/**
 * Founder programme — "first N agents get Pro access".
 *
 * DISABLED BY DEFAULT (FOUNDER_PROMO_ENABLED=false). Do not advertise a free
 * period or a cap in the app until you have enabled and tested this.
 *
 * Fixes over the previous file:
 *  - it now imports its own dependencies (it used undefined `functions`,
 *    `db` and `admin` before) and is wired into index.js
 *  - the one-claim-per-user check happens INSIDE the transaction, using a
 *    unique claim document keyed by uid, so concurrent duplicate claims can
 *    never both succeed
 *  - the slot count and the claim are written in the same transaction, so
 *    the cap cannot be exceeded
 */
const functions = require('firebase-functions/v1');
const { db, FieldValue, Timestamp, DAY_MS } = require('./lib/admin');
const { FOUNDER } = require('./lib/config');

const PROGRAM = db.collection('promotions').doc('founderProgram');

exports.claimFounderPromo = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  if (!FOUNDER.enabled()) throw new functions.https.HttpsError('failed-precondition', 'This offer is not available.');
  const uid = context.auth.uid;
  const claimRef = PROGRAM.collection('claims').doc(uid);
  const userRef = db.collection('users').doc(uid);

  const result = await db.runTransaction(async (t) => {
    const [programSnap, claimSnap, userSnap] = await Promise.all([t.get(PROGRAM), t.get(claimRef), t.get(userRef)]);
    if (!userSnap.exists) throw new functions.https.HttpsError('not-found', 'User profile not found.');
    const user = userSnap.data();
    if (!['agent', 'landlord'].includes(user.role)) {
      throw new functions.https.HttpsError('permission-denied', 'This offer is for agents and landlords who list property.');
    }
    if (claimSnap.exists) throw new functions.https.HttpsError('already-exists', 'You have already claimed this offer.');

    const claimed = (programSnap.exists && programSnap.data().slotsClaimed) || 0;
    const total = FOUNDER.slots();
    if (claimed >= total) return { claimed: false };

    const days = FOUNDER.grantDays();
    const currentEnd = user.premiumExpiresAt ? user.premiumExpiresAt.toMillis() : 0;
    const expiresAt = Timestamp.fromMillis(Math.max(Date.now(), currentEnd) + days * DAY_MS);

    t.set(PROGRAM, {
      slotsClaimed: claimed + 1,
      slotsTotal: total,
      active: claimed + 1 < total,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    t.set(claimRef, { uid, slotNumber: claimed + 1, claimedAt: FieldValue.serverTimestamp(), expiresAt });
    t.update(userRef, {
      premiumPlan: 'agent_pro',
      premiumStartedAt: user.premiumStartedAt || FieldValue.serverTimestamp(),
      premiumExpiresAt: expiresAt,
      founderPromoClaimed: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { claimed: true, slotNumber: claimed + 1, expiresAt: expiresAt.toDate().toISOString() };
  });

  if (!result.claimed) throw new functions.https.HttpsError('resource-exhausted', 'All founding spots have been claimed.');
  return { success: true, slotNumber: result.slotNumber, expiresAt: result.expiresAt };
});
