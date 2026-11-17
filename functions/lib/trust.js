/**
 * Trust — verification review, property passport, reviewer document access.
 *
 * Identity, authority-to-market and title review are SEPARATE checks with
 * their own evidence date, reviewer provenance, expiry and limitation text.
 * Approving one never approves another:
 *
 *   requestType 'identity'      → the person's identity (user document)
 *   requestType 'authority'     → permission to market ONE listing
 *                                 (also accepts legacy 'agent_authority',
 *                                 'landlord_ownership', 'property')
 *   requestType 'title'         → title review of ONE listing (reviewer-led)
 *
 * Private documents are never given a public URL. Reviewers receive a short
 * signed URL that is derived from a request they are allowed to see.
 */
const functions = require('firebase-functions/v1');
const { admin, db, FieldValue, Timestamp, DAY_MS } = require('./admin');

const AUTHORITY_TYPES = ['authority', 'agent_authority', 'landlord_ownership', 'property'];
const DOC_KEYS = ['selfiePath', 'idDocumentPath', 'propertyDocumentPath', 'videoPath'];

function isReviewer(context) {
  return !!(context.auth && (context.auth.token.admin || context.auth.token.reviewer));
}

const LIMITATIONS = {
  identity: 'Identity only. This does not prove ownership or authority to rent out any property.',
  authority: 'Reviewed for this listing only. It does not prove title and does not cover other listings.',
  title: 'A separate review of title evidence supplied. It is not legal advice or a guarantee.',
};

exports.reviewVerificationRequest = functions.https.onCall(async (data, context) => {
  if (!isReviewer(context)) {
    throw new functions.https.HttpsError('permission-denied', 'Reviewer or admin privileges required.');
  }
  const { requestId, decision, reason, expiresInDays } = data || {};
  if (!requestId || !['approved', 'rejected', 'needs_changes'].includes(decision)) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId and a valid decision are required.');
  }
  if (decision !== 'approved' && !(reason && String(reason).trim())) {
    throw new functions.https.HttpsError('invalid-argument', 'Give the applicant a reason they can act on.');
  }

  const reqRef = db.collection('verification_requests').doc(String(requestId));
  const reqSnap = await reqRef.get();
  if (!reqSnap.exists) throw new functions.https.HttpsError('not-found', 'Request not found.');
  const request = reqSnap.data();

  const type = request.requestType === 'identity' ? 'identity'
    : request.requestType === 'title' ? 'title'
      : AUTHORITY_TYPES.includes(request.requestType) ? 'authority' : null;
  if (!type) throw new functions.https.HttpsError('invalid-argument', 'Unknown request type.');

  let listingRef = null;
  if (type !== 'identity') {
    if (!request.listingId) throw new functions.https.HttpsError('failed-precondition', 'This request is not bound to a listing.');
    listingRef = db.collection('listings').doc(request.listingId);
  }

  const days = Math.min(Math.max(parseInt(expiresInDays || (type === 'identity' ? 365 : 180), 10), 1), 730);
  const expiresAt = Timestamp.fromMillis(Date.now() + days * DAY_MS);
  const now = FieldValue.serverTimestamp();
  const audit = { by: context.auth.uid, action: decision, at: new Date().toISOString(), note: reason || null };

  await db.runTransaction(async (t) => {
    if (listingRef) {
      const l = await t.get(listingRef);
      if (!l.exists) throw new functions.https.HttpsError('not-found', 'The listing no longer exists.');
      // The request must be bound to a listing the applicant actually owns.
      if (l.data().agentId !== request.applicantId) {
        throw new functions.https.HttpsError('failed-precondition', 'The applicant does not own this listing.');
      }
    }
    t.update(reqRef, {
      status: decision,
      reviewerId: context.auth.uid,
      reviewedAt: now,
      rejectionReason: reason || null,
      auditHistory: FieldValue.arrayUnion(audit),
      updatedAt: now,
      ...(decision === 'approved' ? { expiresAt } : {}),
    });

    if (type === 'identity') {
      const userRef = db.collection('users').doc(request.applicantId);
      if (decision === 'approved') {
        t.update(userRef, {
          verificationStatus: 'approved',
          verificationType: 'identity',
          verifiedAt: now,
          verifiedBy: context.auth.uid,
          verificationExpiresAt: expiresAt,
          isVerified: true,
          updatedAt: now,
        });
      } else {
        t.update(userRef, { verificationStatus: decision, updatedAt: now });
      }
    } else {
      // Passport entry for ONE listing. Nothing else about the listing or
      // the person changes.
      const entry = {
        state: decision === 'approved' ? 'reviewed' : decision,
        checkedAt: decision === 'approved' ? now : null,
        expiresAt: decision === 'approved' ? expiresAt : null,
        reviewerId: context.auth.uid,
        limitation: LIMITATIONS[type],
        requestId: String(requestId),
      };
      t.update(listingRef, { [`passport.${type}`]: entry, updatedAt: now });
    }
  });
  return { success: true };
});

// Reviewer signed URL — resolved from a request, never from a free-form path.
exports.getReviewDocumentUrl = functions.https.onCall(async (data, context) => {
  if (!isReviewer(context)) {
    throw new functions.https.HttpsError('permission-denied', 'Reviewer or admin privileges required.');
  }
  const { requestId, docKey } = data || {};
  if (!requestId || !DOC_KEYS.includes(docKey)) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId and a valid docKey are required.');
  }
  const snap = await db.collection('verification_requests').doc(String(requestId)).get();
  if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Request not found.');
  const request = snap.data();
  const path = request[docKey];
  const expected = `verification/${request.applicantId}/${snap.id}/`;
  if (!path || !String(path).startsWith(expected)) {
    throw new functions.https.HttpsError('not-found', 'That document is not part of this request.');
  }
  const [url] = await admin.storage().bucket().file(path).getSignedUrl({
    action: 'read', expires: Date.now() + 10 * 60 * 1000,
  });
  await db.collection('verification_requests').doc(snap.id).update({
    auditHistory: FieldValue.arrayUnion({ by: context.auth.uid, action: `viewed_${docKey}`, at: new Date().toISOString() }),
  });
  return { url };
});

// Expire verification entries whose evidence date has passed.
exports.expireVerifications = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const now = Timestamp.now();
  const users = await db.collection('users')
    .where('verificationStatus', '==', 'approved')
    .where('verificationExpiresAt', '<', now).limit(300).get();
  const batch = db.batch();
  users.docs.forEach((d) => batch.update(d.ref, { verificationStatus: 'expired', isVerified: false }));
  await batch.commit();
  console.log(`expireVerifications: expired ${users.size} identity checks.`);
  return null;
});

exports.setAdminOrReviewerClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only an existing admin can grant this claim.');
  }
  const { uid, admin: grantAdmin, reviewer: grantReviewer } = data || {};
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid is required.');
  await admin.auth().setCustomUserClaims(uid, { admin: !!grantAdmin, reviewer: !!grantReviewer || !!grantAdmin });
  return { success: true };
});

module.exports.LIMITATIONS = LIMITATIONS;

// Public, safe-to-show mirror of a user. Contact details, email, saved
// listings, tokens and payment fields are NEVER copied.
exports.syncPublicProfile = functions.firestore.document('users/{uid}').onWrite(async (change, context) => {
  const ref = db.collection('public_profiles').doc(context.params.uid);
  if (!change.after.exists) { await ref.delete().catch(() => {}); return null; }
  const u = change.after.data();
  const identityOk = u.verificationStatus === 'approved' && u.verificationExpiresAt && u.verificationExpiresAt.toMillis() > Date.now();
  await ref.set({
    name: u.name || '',
    photo: u.profilePhoto || null,
    role: u.role || 'tenant',
    agencyName: u.agencyName || null,
    bio: u.bio || null,
    identityChecked: !!identityOk,
    identityCheckedAt: identityOk ? (u.verifiedAt || null) : null,
    identityExpiresAt: identityOk ? u.verificationExpiresAt : null,
    liveListings: u.totalListings || 0,
    memberSince: u.createdAt || null,
  });
  return null;
});
