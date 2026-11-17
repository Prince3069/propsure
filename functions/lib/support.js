/**
 * Support requests and reports — one trackable queue.
 *
 * A report is not "just a database row": it gets a reference number, an
 * acknowledgement, a visible status ladder (received → assigned → outcome)
 * and, for serious reasons, a safety hold on the listing (paid placement is
 * ignored and the listing cannot be promoted while the hold exists).
 */
const functions = require('firebase-functions/v1');
const { db, FieldValue } = require('./admin');
const { SERIOUS_REPORT_REASONS } = require('./config');

const TOPICS = ['listing_issue', 'inspection', 'account_payment', 'report', 'other'];
const REPORT_REASONS = ['no_longer_available', 'incorrect_details', 'authority_concern', 'suspicious_payment', 'other'];

function isReviewer(context) {
  return !!(context.auth && (context.auth.token.admin || context.auth.token.reviewer));
}

async function nextReference() {
  const ref = db.collection('system').doc('supportCounter');
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    const n = ((snap.exists && snap.data().n) || 1000) + 1;
    t.set(ref, { n }, { merge: true });
    return `PS-${n}`;
  });
}

function clean(s, max) {
  return String(s == null ? '' : s).replace(/\s+/g, ' ').trim().slice(0, max);
}

exports.createSupportRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  const uid = context.auth.uid;
  const kind = data && data.kind === 'report' ? 'report' : 'support';
  const topic = TOPICS.includes(data && data.topic) ? data.topic : 'other';
  const message = clean(data && data.message, 500);
  const subject = clean(data && data.subject, 120);
  if (message.length < 5) throw new functions.https.HttpsError('invalid-argument', 'Tell us a little more so we can help.');

  const doc = { kind, topic, subject, message, userId: uid };

  if (kind === 'report') {
    const reason = REPORT_REASONS.includes(data.reason) ? data.reason : 'other';
    const listingId = clean(data.listingId, 80);
    if (!listingId) throw new functions.https.HttpsError('invalid-argument', 'Choose the listing you are reporting.');
    const listingSnap = await db.collection('listings').doc(listingId).get();
    if (!listingSnap.exists) throw new functions.https.HttpsError('not-found', 'Listing not found.');
    doc.reason = reason;
    doc.listingId = listingId;
    doc.listingTitle = listingSnap.data().title || '';
    doc.targetAgentId = listingSnap.data().agentId || null;
  }

  // Evidence paths must live under the caller's own private folder.
  const evidence = Array.isArray(data && data.evidencePaths) ? data.evidencePaths.slice(0, 5) : [];
  doc.evidencePaths = evidence.filter((p) => typeof p === 'string' && p.startsWith(`support/${uid}/`));

  const reference = await nextReference();
  const ref = db.collection('support_requests').doc();
  const batch = db.batch();
  batch.set(ref, {
    ...doc,
    reference,
    status: 'received',
    stages: { received: FieldValue.serverTimestamp(), assigned: null, outcome: null },
    outcomeNote: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (kind === 'report' && SERIOUS_REPORT_REASONS.includes(doc.reason)) {
    batch.update(db.collection('listings').doc(doc.listingId), {
      safetyHold: true,
      safetyHoldAt: FieldValue.serverTimestamp(),
      safetyHoldRef: reference,
    });
  }
  batch.set(db.collection('notifications').doc(), {
    userId: uid,
    type: 'support_received',
    title: kind === 'report' ? 'We received your report' : 'We received your request',
    body: `Reference ${reference}. We'll update you here.`,
    route: `/support/${ref.id}`,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { id: ref.id, reference };
});

exports.updateSupportRequest = functions.https.onCall(async (data, context) => {
  if (!isReviewer(context)) throw new functions.https.HttpsError('permission-denied', 'Reviewer or admin privileges required.');
  const { id, status, note, releaseHold } = data || {};
  if (!id || !['assigned', 'resolved', 'dismissed'].includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'id and a valid status are required.');
  }
  const ref = db.collection('support_requests').doc(String(id));
  const snap = await ref.get();
  if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Request not found.');
  const req = snap.data();
  const patch = { status, updatedAt: FieldValue.serverTimestamp(), assignedTo: context.auth.uid };
  if (status === 'assigned') patch['stages.assigned'] = FieldValue.serverTimestamp();
  else { patch['stages.outcome'] = FieldValue.serverTimestamp(); patch.outcomeNote = clean(note, 500); }
  const batch = db.batch();
  batch.update(ref, patch);
  if (releaseHold && req.listingId && status !== 'assigned') {
    batch.update(db.collection('listings').doc(req.listingId), { safetyHold: false, safetyHoldRef: null });
  }
  batch.set(db.collection('notifications').doc(), {
    userId: req.userId,
    type: 'support_update',
    title: status === 'assigned' ? 'Your request is being reviewed' : 'There is an outcome on your request',
    body: `Reference ${req.reference}.`,
    route: `/support/${snap.id}`,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { success: true };
});

module.exports.TOPICS = TOPICS;
module.exports.REPORT_REASONS = REPORT_REASONS;
