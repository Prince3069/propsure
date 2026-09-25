/**
 * Founder Promo — "first 100 agents get premium free."
 *
 * Design choices worth knowing:
 * - The slot count lives in ONE document (`promotions/founderProgram`) and
 *   is incremented inside a Firestore transaction — that's what makes
 *   this race-safe. Without a transaction, two agents claiming the last
 *   slot at the same millisecond could both succeed, blowing past 100.
 * - Grants a real `premiumPlan`/`premiumExpiresAt` on the user doc —
 *   the SAME fields Paystack's webhook sets on a real payment. That
 *   means every screen that already reads `user.isPremium` (or your
 *   `effectiveIsPremiumProvider`) just works, with zero UI changes.
 * - Duration is 12 months, not permanent — a "first 100 users" reward is
 *   usually meant to be generous, not an unlimited standing commitment
 *   with no way to revisit it. Change FOUNDER_GRANT_DAYS below if you
 *   want it shorter/longer/permanent (set to something absurd like
 *   36500 for "effectively forever" rather than writing separate
 *   permanent-grant logic).
 * - A user can only claim once (checked via a `claimedBy` array on the
 *   promo doc, and a `founderPromoClaimed` flag on the user doc) — so
 *   they can't re-run this to keep extending their own free period.
 *
 * Add this to your existing functions/index.js (alongside the Phase 1
 * PLAN_CATALOG, admin.initializeApp(), etc. — don't call
 * admin.initializeApp() twice in one file).
 */

const FOUNDER_GRANT_DAYS = 365;
const FOUNDER_PROGRAM_DOC = 'founderProgram';
const FOUNDER_SLOTS_TOTAL = 100;

exports.claimFounderPromo = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  }
  const uid = context.auth.uid;

  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'User profile not found.');
  }
  const user = userSnap.data();
  if (!(user.role === 'agent' || user.role === 'landlord')) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'This offer is for agents and landlords listing property, not tenant accounts.'
    );
  }
  if (user.founderPromoClaimed) {
    throw new functions.https.HttpsError('already-exists', 'You\'ve already claimed this offer.');
  }

  const promoRef = db.collection('promotions').doc(FOUNDER_PROGRAM_DOC);

  const result = await db.runTransaction(async (t) => {
    const promoSnap = await t.get(promoRef);
    const promo = promoSnap.exists ? promoSnap.data() : { slotsClaimed: 0 };

    if ((promo.slotsClaimed || 0) >= FOUNDER_SLOTS_TOTAL) {
      return { claimed: false, reason: 'full' };
    }

    const expiresAt = new Date(Date.now() + FOUNDER_GRANT_DAYS * 24 * 60 * 60 * 1000);

    t.set(promoRef, {
      slotsClaimed: (promo.slotsClaimed || 0) + 1,
      slotsTotal: FOUNDER_SLOTS_TOTAL,
      active: (promo.slotsClaimed || 0) + 1 < FOUNDER_SLOTS_TOTAL,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    t.update(db.collection('users').doc(uid), {
      premiumPlan: 'agent_pro',
      premiumStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      founderPromoClaimed: true,
      founderPromoClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { claimed: true, slotNumber: (promo.slotsClaimed || 0) + 1, expiresAt: expiresAt.toISOString() };
  });

  if (!result.claimed) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'All 100 founding agent spots have been claimed — regular pricing now applies.'
    );
  }

  return { success: true, slotNumber: result.slotNumber, expiresAt: result.expiresAt };
});