/**
 * Propsure media worker (Cloud Run).
 *
 * Cloud Scheduler calls POST /run every minute (authenticated with an OIDC
 * token; deploy with --no-allow-unauthenticated). Each call claims at most
 * one queued job inside a Firestore transaction, so two instances can never
 * process the same upload, and a crashed instance's job is re-claimed once
 * its lease expires. Job ids are derived from the object generation by the
 * `onOriginalVideoFinalized` function, which makes the whole path
 * retry-safe.
 */
const http = require('http');
const fs = require('fs'); const os = require('os'); const path = require('path');
const admin = require('firebase-admin');
const A = require('./analyze');
const FP = require('./fingerprint');

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const LIMITS = { minVideoSeconds: 5, maxVideoSeconds: 180 };
const LEASE_MS = 20 * 60 * 1000;
// Videos longer than this skip steadying so a long job stays inside the request timeout.
const STEADY_MAX_SECONDS = 120;
const MAX_ATTEMPTS = 3;

async function claimJob() {
  const now = Date.now();
  let snap = await db.collection('media_jobs').where('status', '==', 'queued').limit(1).get();
  if (snap.empty) {
    snap = await db.collection('media_jobs').where('status', '==', 'processing').where('leaseUntilMs', '<', now).limit(1).get();
  }
  if (snap.empty) return null;
  const ref = snap.docs[0].ref;
  return db.runTransaction(async (t) => {
    const cur = await t.get(ref);
    const j = cur.data();
    const claimable = j.status === 'queued' || (j.status === 'processing' && j.leaseUntilMs < Date.now());
    if (!claimable) return null;
    t.update(ref, { status: 'processing', attempts: (j.attempts || 0) + 1, leaseUntilMs: Date.now() + LEASE_MS, startedAt: FieldValue.serverTimestamp() });
    return { id: ref.id, ...j, attempts: (j.attempts || 0) + 1 };
  });
}

async function setListing(listingId, patch) {
  await db.collection('listings').doc(listingId).set({ ...patch, videoStatusAt: FieldValue.serverTimestamp() }, { merge: true });
}

async function processJob(job) {
  const startedMs = Date.now();
  const timing = {};
  const lap = (k, t0) => { timing[k] = Date.now() - t0; };
  const bucket = admin.storage().bucket(job.bucket);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'job-'));
  const local = path.join(tmp, 'original');
  try {
    await setListing(job.listingId, { videoStatus: 'processing' });
    await bucket.file(job.path).download({ destination: local });

    const info = await A.probe(local);
    const problem = A.validate(info, LIMITS);
    if (problem) {
      await db.collection('media_jobs').doc(job.id).update({ status: 'rejected', reason: problem });
      await setListing(job.listingId, { videoStatus: 'rejected', videoRejectionReason: problem });
      await bucket.file(job.path).delete().catch(() => {});
      return;
    }

    let t0 = Date.now();
    const frames = await A.sampleMetrics(local);
    lap('sampleMs', t0);
    const sel = A.selectCandidates(frames, { max: 24 });
    const issues = A.analyzeQuality(frames, info);
    const okMeans = frames.filter((f) => f.mean >= 45 && f.mean <= 220).map((f) => f.mean);
    const meanLuma = okMeans.length ? A.median(okMeans) : 120;
    // Footage checks: same video posted before, or filmed long before this upload.
    const flags = [];
    const hashes = FP.makeFingerprint(frames);
    try {
      const prev = await db.collection('video_fingerprints').orderBy('createdAt', 'desc').limit(500).get();
      const others = prev.docs.map((d) => ({ jobId: d.id, ...d.data() }));
      for (const f of FP.findMatches(hashes, others, { jobId: job.id, listingId: job.listingId, ownerUid: job.ownerUid })) flags.push(f);
    } catch (e) { console.error('fingerprint compare failed', e.message); }
    const old = FP.oldFootage(info.creationTime);
    if (old) flags.push({ type: 'old_footage', daysOld: old.daysOld });
    const base = `listing_candidates/${job.listingId}/${job.id}`;
    const candidates = [];
    let posterSrc = null;
    t0 = Date.now();
    for (let i = 0; i < sel.chosen.length; i++) {
      const c = sel.chosen[i];
      const out = path.join(tmp, `f${i}.jpg`);
      // The sharpest frame within about half a second of the pick, lightly corrected.
      const atMs = await A.bestFrame(local, c.tSec, out, { meanLuma: c.mean, tmpDir: tmp });
      const dest = `${base}/frame_${i}.jpg`;
      await bucket.upload(out, { destination: dest, contentType: 'image/jpeg' });
      candidates.push({ id: `f${i}`, path: dest, timestampMs: atMs, label: null, scene: c.scene, role: c.role });
      if (!posterSrc && c.role === 'wide') posterSrc = out;
    }

    lap('framesMs', t0);
    // The shared video: same walk-through at the same pace, lightly corrected and steadied.
    const dbase = `listing_derivatives/${job.listingId}/${job.id}`;
    t0 = Date.now();
    const trf = info.durationSec <= STEADY_MAX_SECONDS ? await A.detectShake(local, path.join(tmp, 'shake.trf')) : null;
    const p720 = path.join(tmp, 'p720.mp4'); const p360 = path.join(tmp, 'p360.mp4');
    await A.transcode(local, p720, 720, 24, { meanLuma, trf });
    await A.transcode(p720, p360, 360, 28, { enhance: false });
    await bucket.upload(p720, { destination: `${dbase}/video_720.mp4`, contentType: 'video/mp4' });
    await bucket.upload(p360, { destination: `${dbase}/video_360.mp4`, contentType: 'video/mp4' });
    lap('videoMs', t0);
    if (!posterSrc) {
      posterSrc = path.join(tmp, 'poster.jpg');
      await A.extractFrame(local, Math.min(1, info.durationSec / 2), posterSrc);
    }
    await bucket.upload(posterSrc, { destination: `${dbase}/poster.jpg`, contentType: 'image/jpeg' });

    const coverageText = sel.coverageWarning ? 'This video may not show every room. You can add real photos or film it again.' : null;
    await db.collection('media_jobs').doc(job.id).update({
      status: 'needs_review',
      candidates,
      scenes: sel.scenes,
      issues,
      coverageWarning: sel.coverageWarning,
      enhanced: { light: true, steadied: !!trf },
      derivatives: { p720: `${dbase}/video_720.mp4`, p360: `${dbase}/video_360.mp4`, poster: `${dbase}/poster.jpg` },
      durationSec: Math.round(info.durationSec), width: info.width, height: info.height,
      recordedAt: info.creationTime ? admin.firestore.Timestamp.fromDate(new Date(info.creationTime)) : null,
      flags,
      processedAt: FieldValue.serverTimestamp(),
      timing: { ...timing, totalMs: Date.now() - startedMs, attempt: job.attempts },
    });
    await db.collection('video_fingerprints').doc(job.id).set({ listingId: job.listingId, ownerUid: job.ownerUid || null, hashes, createdAt: FieldValue.serverTimestamp() });
    for (const f of flags) {
      await db.collection('media_flags').add({ ...f, jobId: job.id, listingId: job.listingId, ownerUid: job.ownerUid || null, status: 'open', createdAt: FieldValue.serverTimestamp() });
    }
    console.log('job done', JSON.stringify({ job: job.id, sec: Math.round(info.durationSec), ...timing, totalMs: Date.now() - startedMs, flags: flags.length }));
    // Frame PATHS (not images) are mirrored on the listing so the owner's app can
    // fetch download URLs; storage rules only let the owner read those files.
    await setListing(job.listingId, {
      videoStatus: 'needs_review',
      videoCoverageWarning: coverageText,
      videoIssues: issues,
      videoSteadied: !!trf,
      videoNeedsCheck: flags.length > 0,
      videoCandidates: candidates.map((c) => ({ id: c.id, path: c.path, timestampMs: c.timestampMs, scene: c.scene, role: c.role })),
    });
  } catch (e) {
    console.error('job failed', job.id, e);
    const final = job.attempts >= MAX_ATTEMPTS;
    await db.collection('media_jobs').doc(job.id).update({ status: final ? 'failed' : 'queued', lastError: String(e.message || e).slice(0, 300) });
    if (final) await setListing(job.listingId, { videoStatus: 'failed', videoRejectionReason: 'We could not process that video. Try again or add photos.' });
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/healthz') { res.writeHead(200); return res.end('ok'); }
  if (req.method !== 'POST' || req.url !== '/run') { res.writeHead(404); return res.end(); }
  try {
    const job = await claimJob();
    if (job) await processJob(job);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ processed: job ? job.id : null }));
  } catch (e) {
    console.error(e); res.writeHead(500); res.end('error');
  }
}).listen(process.env.PORT || 8080);
