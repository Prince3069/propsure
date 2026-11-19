/**
 * Video-first media pipeline (server side).
 *
 *  client ─ resumable upload ─▶ listing_originals/{listingId}/{uploadId}/original.*   (PRIVATE, write-once)
 *        onOriginalVideoFinalized  (this file)  validates + creates an idempotent job
 *        media_worker (Cloud Run, see /media_worker)  probes, makes a poster,
 *            360p/720p derivatives and CANDIDATE stills from the real footage
 *            → listing_derivatives/… and listing_candidates/…  (PRIVATE)
 *        status: uploaded → validating → processing → needs_review → ready
 *                                                   ↘ failed | rejected
 *  agent ─ Review your video stills ─▶ confirmVideoFrames  (this file)
 *        copies ONLY the reviewed derivatives/frames to public paths and
 *        records provenance (source: video, timestamp) for every still.
 *
 * We never generate, stage or beautify a missing room. If footage is blurry,
 * dark or incomplete the agent is asked for real photos instead.
 */
const functions = require('firebase-functions/v1');
const crypto = require('crypto');
const { admin, db, FieldValue, Timestamp, DAY_MS } = require('./admin');
const { MEDIA } = require('./config');

const ORIGINAL_RE = /^listing_originals\/([^/]+)\/([^/]+)\/[^/]+$/;

function jobIdFor(object) {
  return crypto.createHash('sha1').update(`${object.bucket}|${object.name}|${object.generation}`).digest('hex');
}

async function setVideoState(listingId, status, extra = {}) {
  await db.collection('listings').doc(listingId).set({
    videoStatus: status,
    videoStatusAt: FieldValue.serverTimestamp(),
    ...extra,
  }, { merge: true });
}

exports.onOriginalVideoFinalized = functions.storage.object().onFinalize(async (object) => {
  const m = ORIGINAL_RE.exec(object.name || '');
  if (!m) return null;
  const [, listingId, uploadId] = m;
  const jobId = jobIdFor(object);
  const jobRef = db.collection('media_jobs').doc(jobId);

  const reject = async (reason, status = 'rejected') => {
    await setVideoState(listingId, status, { videoRejectionReason: reason });
    await jobRef.set({ listingId, uploadId, path: object.name, status, reason, createdAt: FieldValue.serverTimestamp() }, { merge: true });
    // Rejected originals are removed; nothing unvalidated is kept.
    try { await admin.storage().bucket(object.bucket).file(object.name).delete(); } catch (_) { /* ignore */ }
  };

  const listingSnap = await db.collection('listings').doc(listingId).get();
  if (!listingSnap.exists) return reject('Listing does not exist.');
  const listing = listingSnap.data();
  const owner = object.metadata && object.metadata.ownerUid;
  if (!owner || owner !== listing.agentId) return reject('Upload was not made by the listing owner.');
  if (!MEDIA.allowedVideoTypes.includes(object.contentType)) return reject('That file type is not supported. Use MP4 or MOV.');
  if (Number(object.size) > MEDIA.maxVideoBytes) return reject('That video is too large. Keep it under 300 MB.');

  // Idempotent: a retried event for the same object generation creates nothing new.
  try {
    await jobRef.create({
      listingId, uploadId, bucket: object.bucket, path: object.name, generation: String(object.generation),
      sizeBytes: Number(object.size), contentType: object.contentType, ownerUid: owner,
      status: 'queued', attempts: 0, createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    if (e.code === 6 || /already exists/i.test(String(e.message))) return null; // ALREADY_EXISTS
    throw e;
  }
  await setVideoState(listingId, 'uploaded', { activeMediaJobId: jobId, videoRejectionReason: null });
  return null;
});

function publicUrl(bucketName, path, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

async function publishObject(fromPath, toPath, contentType) {
  const bucket = admin.storage().bucket();
  const token = crypto.randomUUID();
  await bucket.file(fromPath).copy(bucket.file(toPath));
  await bucket.file(toPath).setMetadata({ contentType, metadata: { firebaseStorageDownloadTokens: token } });
  return publicUrl(bucket.name, toPath, token);
}

// The agent has looked at the candidates and chosen what to publish.
exports.confirmVideoFrames = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  const uid = context.auth.uid;
  const { listingId, frameIds = [], coverId, labels = {} } = data || {};
  if (!listingId) throw new functions.https.HttpsError('invalid-argument', 'listingId is required.');
  const listingRef = db.collection('listings').doc(String(listingId));
  const listingSnap = await listingRef.get();
  if (!listingSnap.exists) throw new functions.https.HttpsError('not-found', 'Listing not found.');
  const listing = listingSnap.data();
  if (listing.agentId !== uid) throw new functions.https.HttpsError('permission-denied', 'This is not your listing.');
  if (listing.videoStatus !== 'needs_review') throw new functions.https.HttpsError('failed-precondition', 'There is no video waiting for review.');

  const jobSnap = await db.collection('media_jobs').doc(String(listing.activeMediaJobId)).get();
  if (!jobSnap.exists) throw new functions.https.HttpsError('not-found', 'Media job not found.');
  const job = jobSnap.data();
  const candidates = job.candidates || [];
  const chosen = [];
  for (const id of (Array.isArray(frameIds) ? frameIds : []).slice(0, MEDIA.maxStills)) {
    const c = candidates.find((x) => x.id === id);
    if (c) chosen.push(c);
  }
  if (chosen.length === 0 && !(listing.images && listing.images.length)) {
    throw new functions.https.HttpsError('failed-precondition', 'Choose at least one frame, or add real photos to your listing.');
  }

  const base = `listings/${listingId}/media`;
  const stills = [];
  const imageUrls = [];
  let coverUrl = null;
  for (const c of chosen) {
    const url = await publishObject(c.path, `${base}/still_${c.id}.jpg`, 'image/jpeg');
    const label = typeof labels[c.id] === 'string' ? labels[c.id].slice(0, 24) : null;
    stills.push({ url, source: 'video', timestampMs: c.timestampMs, label, jobId: jobSnap.id });
    imageUrls.push(url);
    if (coverId && c.id === coverId) coverUrl = url;
  }
  const videoUrl = job.derivatives && job.derivatives.p720 ? await publishObject(job.derivatives.p720, `${base}/video_720.mp4`, 'video/mp4') : null;
  const videoLowUrl = job.derivatives && job.derivatives.p360 ? await publishObject(job.derivatives.p360, `${base}/video_360.mp4`, 'video/mp4') : null;
  const posterUrl = job.derivatives && job.derivatives.poster ? await publishObject(job.derivatives.poster, `${base}/poster.jpg`, 'image/jpeg') : null;

  // Cover first, then existing photos, then new stills — existing evidence is never removed.
  const existing = Array.isArray(listing.images) ? listing.images : [];
  const ordered = [];
  if (coverUrl) ordered.push(coverUrl);
  for (const u of [...existing, ...imageUrls]) if (!ordered.includes(u)) ordered.push(u);

  await listingRef.update({
    images: ordered,
    ...(stills.length ? { stills: FieldValue.arrayUnion(...stills) } : {}),
    videoUrl, videoLowUrl, posterUrl,
    videoDurationSec: job.durationSec || null,
    videoStatus: 'ready',
    videoCandidates: [],
    videoStatusAt: FieldValue.serverTimestamp(),
    videoRecordedAt: job.recordedAt || FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await jobSnap.ref.update({ status: 'ready', confirmedAt: FieldValue.serverTimestamp() });
  return { success: true, stills: stills.length };
});

// The agent renames the rooms on stills that are already published
// (for example "Kitchen"). Only the label text can change here.
exports.updateStillLabels = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  const { listingId, labels } = data || {};
  if (!listingId || !Array.isArray(labels)) throw new functions.https.HttpsError('invalid-argument', 'listingId and labels are required.');
  const ref = db.collection('listings').doc(String(listingId));
  const snap = await ref.get();
  if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Listing not found.');
  const listing = snap.data();
  if (listing.agentId !== context.auth.uid) throw new functions.https.HttpsError('permission-denied', 'This is not your listing.');
  const byUrl = new Map();
  for (const item of labels.slice(0, 40)) {
    if (item && typeof item.url === 'string') {
      const text = typeof item.label === 'string' ? item.label.trim().slice(0, 24) : '';
      byUrl.set(item.url, text || null);
    }
  }
  const stills = (Array.isArray(listing.stills) ? listing.stills : []).map((s) => (byUrl.has(s.url) ? { ...s, label: byUrl.get(s.url) } : s));
  await ref.update({ stills, updatedAt: FieldValue.serverTimestamp() });
  return { success: true };
});

// The agent rejects the processed video (wrong clip, private content…).
exports.discardVideo = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  const { listingId } = data || {};
  const ref = db.collection('listings').doc(String(listingId || '_'));
  const snap = await ref.get();
  if (!snap.exists || snap.data().agentId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'This is not your listing.');
  }
  await ref.update({
    videoStatus: 'none', videoUrl: null, videoLowUrl: null, posterUrl: null,
    videoDurationSec: null, activeMediaJobId: null, videoCandidates: [], updatedAt: FieldValue.serverTimestamp(),
  });
  return { success: true };
});

// Candidate frames from jobs that were never confirmed are removed after 14 days.
exports.cleanupMediaCandidates = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - 14 * DAY_MS);
  const jobs = await db.collection('media_jobs').where('status', '==', 'needs_review').where('processedAt', '<', cutoff).limit(100).get();
  const bucket = admin.storage().bucket();
  for (const j of jobs.docs) {
    try { await bucket.deleteFiles({ prefix: `listing_candidates/${j.data().listingId}/${j.id}/` }); } catch (_) { /* ignore */ }
    await j.ref.update({ status: 'expired', candidates: [] });
  }
  console.log(`cleanupMediaCandidates: expired ${jobs.size} unreviewed jobs.`);
  return null;
});

module.exports.jobIdFor = jobIdFor;
module.exports.ORIGINAL_RE = ORIGINAL_RE;
