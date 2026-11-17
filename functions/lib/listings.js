/**
 * Listing lifecycle — the ONLY code path that makes a listing public or
 * changes its availability evidence. Clients can create/edit DRAFTS (see
 * firestore.rules) but cannot set status, featured, verification, quota
 * counters or availability dates themselves.
 *
 *   draft ──publishListing──▶ active ──(7d no confirmation)──▶ needs refresh
 *                               │                                    │
 *                               │                    (21d)──▶ stale ◀┘
 *                               ▼                              │
 *             setListingStatus(paused|rented|archived)   confirmAvailability
 *                               │                              ▼
 *                    publishListing (resume)                 active
 */
const functions = require('firebase-functions/v1');
const { db, FieldValue, Timestamp, DAY_MS, isPremiumUser } = require('./admin');
const { activeListingLimit, REFRESH_AFTER_DAYS, HIDE_AFTER_DAYS } = require('./config');

const CATEGORIES = ['for_rent', 'for_sale', 'short_stay', 'commercial'];
const LIVE = ['active', 'stale'];

function requireAuth(context) {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  return context.auth.uid;
}

/** Returns an array of plain-language problems; empty means publishable. */
function publishProblems(listing) {
  const problems = [];
  if (!listing.title || String(listing.title).trim().length < 8) problems.push('Add a clearer title (at least 8 characters).');
  if (!(listing.price > 0)) problems.push('Add the price.');
  if (!CATEGORIES.includes(listing.category)) problems.push('Choose rent, sale, short stay or commercial.');
  if (!listing.location || !listing.location.area) problems.push('Add the area.');
  const hasCover = Array.isArray(listing.images) && listing.images.length > 0;
  if (!hasCover) problems.push('Add at least one real photo or confirm frames from your video.');
  if (listing.videoStatus && ['uploaded', 'validating', 'processing'].includes(listing.videoStatus)) {
    problems.push('Your video is still processing. Publish once it is ready, or publish with photos only.');
  }
  if (Array.isArray(listing.charges)) {
    for (const c of listing.charges) {
      if (!(c.amount >= 0) || !c.type) { problems.push('One of the move-in charges is incomplete.'); break; }
    }
  }
  return problems;
}

exports.publishListing = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { listingId, availabilityConfirmed } = data || {};
  if (!listingId) throw new functions.https.HttpsError('invalid-argument', 'listingId is required.');
  if (availabilityConfirmed !== true) {
    throw new functions.https.HttpsError('failed-precondition', 'Confirm that this home is still available before publishing.');
  }

  const listingRef = db.collection('listings').doc(String(listingId));
  const userRef = db.collection('users').doc(uid);

  return db.runTransaction(async (t) => {
    const [listingSnap, userSnap] = await Promise.all([t.get(listingRef), t.get(userRef)]);
    if (!listingSnap.exists) throw new functions.https.HttpsError('not-found', 'Listing not found.');
    if (!userSnap.exists) throw new functions.https.HttpsError('failed-precondition', 'Create your profile first.');
    const listing = listingSnap.data();
    const user = userSnap.data();

    if (listing.agentId !== uid) throw new functions.https.HttpsError('permission-denied', 'This is not your listing.');
    if (!['agent', 'landlord'].includes(user.role)) {
      throw new functions.https.HttpsError('permission-denied', 'Switch to a listing account to publish.');
    }
    if (!['draft', 'paused', 'rented', 'archived'].includes(listing.status)) {
      throw new functions.https.HttpsError('failed-precondition', `A ${listing.status} listing cannot be published.`);
    }
    if (listing.safetyHold) {
      throw new functions.https.HttpsError('failed-precondition', 'This listing is under review and cannot be published right now.');
    }
    const problems = publishProblems(listing);
    if (problems.length) throw new functions.https.HttpsError('failed-precondition', problems.join(' '));

    const limit = activeListingLimit(isPremiumUser(user));
    const live = user.totalListings || 0;
    if (live >= limit) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Your plan allows ${limit} live listings. Pause or archive one, or upgrade.`
      );
    }

    t.update(listingRef, {
      status: 'active',
      publishedAt: listing.publishedAt || FieldValue.serverTimestamp(),
      availabilityConfirmedAt: FieldValue.serverTimestamp(),
      availabilityConfirmedBy: 'agent',
      needsRefresh: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
    t.update(userRef, { totalListings: live + 1, updatedAt: FieldValue.serverTimestamp() });
    return { success: true };
  });
});

exports.confirmAvailability = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { listingId } = data || {};
  if (!listingId) throw new functions.https.HttpsError('invalid-argument', 'listingId is required.');
  const ref = db.collection('listings').doc(String(listingId));
  await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Listing not found.');
    const l = snap.data();
    if (l.agentId !== uid) throw new functions.https.HttpsError('permission-denied', 'This is not your listing.');
    if (!LIVE.includes(l.status)) throw new functions.https.HttpsError('failed-precondition', 'Only live listings can be confirmed.');
    t.update(ref, {
      status: 'active',
      availabilityConfirmedAt: FieldValue.serverTimestamp(),
      availabilityConfirmedBy: 'agent',
      needsRefresh: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { success: true };
});

// Owner-initiated moves out of the live set. Keeps the quota counter exact.
exports.setListingStatus = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const { listingId, status } = data || {};
  if (!listingId || !['paused', 'rented', 'archived'].includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'listingId and a valid status are required.');
  }
  const ref = db.collection('listings').doc(String(listingId));
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (t) => {
    const [snap, userSnap] = await Promise.all([t.get(ref), t.get(userRef)]);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Listing not found.');
    const l = snap.data();
    if (l.agentId !== uid) throw new functions.https.HttpsError('permission-denied', 'This is not your listing.');
    const wasLive = LIVE.includes(l.status);
    const patch = { status, updatedAt: FieldValue.serverTimestamp() };
    if (status === 'archived') { patch.archivedAt = FieldValue.serverTimestamp(); patch.archivedBy = uid; }
    if (status === 'rented') { patch.rentedAt = FieldValue.serverTimestamp(); }
    if (l.isFeatured && status !== 'paused') { patch.isFeatured = false; patch.featuredUntil = null; }
    t.update(ref, patch);
    if (wasLive) {
      const live = (userSnap.exists && userSnap.data().totalListings) || 0;
      t.update(userRef, { totalListings: Math.max(0, live - 1) });
    }
  });
  return { success: true };
});

// ── Freshness job ─────────────────────────────────────────────────────────
// Daily: flag homes whose availability has not been confirmed recently,
// hide them after the grace period, and tell the agent. Agent confirmation
// and independent visits are stored separately (availabilityConfirmedBy).
exports.refreshFreshness = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const refreshCutoff = Timestamp.fromMillis(Date.now() - REFRESH_AFTER_DAYS * DAY_MS);
  const hideCutoff = Timestamp.fromMillis(Date.now() - HIDE_AFTER_DAYS * DAY_MS);
  const snap = await db.collection('listings').where('status', '==', 'active')
    .where('availabilityConfirmedAt', '<', refreshCutoff).limit(400).get();

  let flagged = 0; let hidden = 0;
  let batch = db.batch(); let ops = 0;
  const flush = async () => { if (ops) { await batch.commit(); batch = db.batch(); ops = 0; } };

  for (const doc of snap.docs) {
    const l = doc.data();
    const confirmed = l.availabilityConfirmedAt;
    if (confirmed.toMillis() < hideCutoff.toMillis()) {
      batch.update(doc.ref, { status: 'stale', needsRefresh: true, updatedAt: FieldValue.serverTimestamp() });
      hidden++;
    } else if (!l.needsRefresh) {
      batch.update(doc.ref, { needsRefresh: true, updatedAt: FieldValue.serverTimestamp() });
      flagged++;
    } else {
      continue;
    }
    batch.set(db.collection('notifications').doc(), {
      userId: l.agentId,
      type: 'availability_refresh',
      title: 'Availability needs a refresh',
      body: `${l.title || 'A listing'} needs a quick availability confirmation.`,
      route: `/profile/listings`,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    ops += 2;
    if (ops >= 400) await flush();
  }
  await flush();
  console.log(`refreshFreshness: flagged ${flagged}, hidden ${hidden}.`);
  return null;
});

module.exports.publishProblems = publishProblems;
