/**
 * Propsure Cloud Functions — Phase 1 (P0 correctness & trust)
 *
 * These functions are what actually enforces the trust rules that
 * firestore.rules can describe but can't compute on its own: verifying a
 * Paystack webhook signature, deriving a price server-side, and moving a
 * verification request through its review lifecycle. Deploy with:
 *
 *   cd functions && npm install
 *   firebase functions:config:set paystack.secret_key="sk_live_xxx" paystack.webhook_secret="sk_live_xxx"
 *   firebase deploy --only functions
 *
 * (Paystack doesn't issue a separate webhook secret — the same secret key
 * is used to verify the `x-paystack-signature` header. Store it via
 * functions config, or migrate to `firebase functions:secrets:set` if
 * you're on 2nd-gen functions; either way, IT MUST NEVER be in the Flutter
 * app or committed to source control.)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const fetch = require('node-fetch');

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

// ────────────────────────────────────────────────────────────────────────
// SERVER-SIDE PLAN CATALOG — the single source of truth for pricing.
// The Flutter app may SHOW these prices to the user for UX, but the
// amount actually charged and the entitlement actually granted always
// come from here, never from anything the client sends. Keep this in
// sync with the display prices in boost_listing_screen.dart and
// premium_screen.dart when you change a price.
// ────────────────────────────────────────────────────────────────────────
const PLAN_CATALOG = {
  boost_7: { amountKobo: 500000, type: 'boost', boostDays: 7 },
  boost_14: { amountKobo: 1000000, type: 'boost', boostDays: 14 },
  boost_30: { amountKobo: 2000000, type: 'boost', boostDays: 30 },
  agent_pro_monthly: { amountKobo: 1000000, type: 'premium', planId: 'agent_pro', durationDays: 30 },
  agent_pro_yearly: { amountKobo: 10000000, type: 'premium', planId: 'agent_pro', durationDays: 365 },
  agent_elite_monthly: { amountKobo: 2500000, type: 'premium', planId: 'agent_elite', durationDays: 30 },
  agent_elite_yearly: { amountKobo: 25000000, type: 'premium', planId: 'agent_elite', durationDays: 365 },
};

// SECRET CONFIG: `functions.config()` / `firebase functions:config:set` is
// dead — the Google Cloud Runtime Configuration API it depended on was
// shut down December 31, 2025, and those CLI commands no longer work at
// all. This now reads from a `.env` file instead (Firebase Functions has
// had native dotenv support since 2022 — this isn't a workaround, it's
// the currently-supported approach for both 1st and 2nd gen functions).
// See PHASE1_README.md for exactly how to create functions/.env.
function paystackSecretKey() {
  const key = process.env.PAYSTACK_SECRET_KEY;
  if (!key) throw new Error('PAYSTACK_SECRET_KEY is not set. Create functions/.env with PAYSTACK_SECRET_KEY=sk_... — see PHASE1_README.md.');
  return key;
}

async function verifyAuth(req) {
  const authHeader = req.headers.authorization || '';
  const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!idToken) throw new Error('Missing Authorization bearer token.');
  return auth.verifyIdToken(idToken);
}

// ────────────────────────────────────────────────────────────────────────
// initializePaystackTransaction
// Client sends ONLY { planId, metadata, callbackUrl }. This function looks
// up the real price, creates the transaction document itself (bypassing
// firestore.rules via the Admin SDK — the rules exist to block the CLIENT,
// not this trusted server code), then calls Paystack.
// ────────────────────────────────────────────────────────────────────────
exports.initializePaystackTransaction = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');

  try {
    const decoded = await verifyAuth(req);
    const uid = decoded.uid;
    const { planId, metadata = {}, callbackUrl } = req.body || {};

    const plan = PLAN_CATALOG[planId];
    if (!plan) return res.status(400).json({ error: `Unknown planId: ${planId}` });

    // Boost-specific guard: you can only pay to boost YOUR OWN listing —
    // the review specifically calls out "prevent a user from paying for a
    // boost on another user's listing."
    if (plan.type === 'boost') {
      const listingId = metadata.listingId;
      if (!listingId) return res.status(400).json({ error: 'metadata.listingId is required for a boost.' });
      const listingSnap = await db.collection('listings').doc(listingId).get();
      if (!listingSnap.exists) return res.status(404).json({ error: 'Listing not found.' });
      if (listingSnap.data().agentId !== uid) {
        return res.status(403).json({ error: 'You can only boost your own listing.' });
      }
    }

    const userSnap = await db.collection('users').doc(uid).get();
    const userEmail = decoded.email || (userSnap.exists && userSnap.data().email) || `${uid}@propsure.temp`;

    const reference = `propsure_${crypto.randomBytes(16).toString('hex')}`;

    // Strip anything metadata might contain that looks like a price
    // override — defense in depth even though nothing above reads it.
    const sanitizedMetadata = { ...metadata };
    delete sanitizedMetadata.amount;
    delete sanitizedMetadata.amountKobo;
    delete sanitizedMetadata.price;

    await db.collection('transactions').doc(reference).set({
      reference,
      userId: uid,
      userEmail,
      planId,
      type: plan.type,
      amountKobo: plan.amountKobo,
      amountNGN: plan.amountKobo / 100,
      metadata: sanitizedMetadata,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const paystackRes = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${paystackSecretKey()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: userEmail,
        amount: plan.amountKobo,
        reference,
        callback_url: callbackUrl,
        metadata: { ...sanitizedMetadata, planId, uid },
      }),
    });
    const paystackData = await paystackRes.json();

    if (!paystackData.status) {
      await db.collection('transactions').doc(reference).update({ status: 'failed' });
      return res.status(502).json({ error: paystackData.message || 'Paystack initialization failed.' });
    }

    return res.status(200).json({
      authorization_url: paystackData.data.authorization_url,
      reference,
    });
  } catch (e) {
    console.error('initializePaystackTransaction error:', e);
    return res.status(401).json({ error: e.message || 'Unauthorized' });
  }
});

// ────────────────────────────────────────────────────────────────────────
// paystackWebhook — the ONLY place entitlements are actually granted.
// Verifies the signature, then grants inside a Firestore transaction so a
// retried/duplicated webhook call can never double-grant (idempotency —
// "prevent duplicate boosts or repeated premium grants for one
// transaction").
// ────────────────────────────────────────────────────────────────────────
exports.paystackWebhook = functions.https.onRequest(async (req, res) => {
  const signature = req.headers['x-paystack-signature'];
  const expected = crypto
    .createHmac('sha512', paystackSecretKey())
    .update(req.rawBody)
    .digest('hex');

  if (!signature || signature !== expected) {
    console.warn('paystackWebhook: signature mismatch — rejecting.');
    return res.status(401).send('Invalid signature');
  }

  const event = req.body;
  if (event.event !== 'charge.success') {
    return res.status(200).send('Ignored (not a charge.success event)');
  }

  const data = event.data;
  const reference = data.reference;
  const txRef = db.collection('transactions').doc(reference);

  try {
    await db.runTransaction(async (t) => {
      const txSnap = await t.get(txRef);
      if (!txSnap.exists) {
        console.warn(`paystackWebhook: unknown reference ${reference}`);
        return;
      }
      const tx = txSnap.data();

      // Idempotency guard — if we've already processed this reference as
      // successful, do nothing. A webhook can legitimately be delivered
      // more than once.
      if (tx.status === 'success') return;

      // Amount tampering guard — the amount Paystack actually charged
      // must match what we told it to charge when we initialized.
      if (data.amount !== tx.amountKobo) {
        t.update(txRef, {
          status: 'failed',
          failureReason: `Amount mismatch: expected ${tx.amountKobo}, got ${data.amount}`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      t.update(txRef, {
        status: 'success',
        webhookEventId: event.id || data.id || null,
        paystackTransactionId: data.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const plan = PLAN_CATALOG[tx.planId];
      if (!plan) return;

      if (plan.type === 'boost') {
        const listingId = tx.metadata && tx.metadata.listingId;
        if (listingId) {
          const featuredUntil = new Date(Date.now() + plan.boostDays * 24 * 60 * 60 * 1000);
          t.update(db.collection('listings').doc(listingId), {
            isFeatured: true,
            featuredUntil: admin.firestore.Timestamp.fromDate(featuredUntil),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } else if (plan.type === 'premium') {
        const expiresAt = new Date(Date.now() + plan.durationDays * 24 * 60 * 60 * 1000);
        t.update(db.collection('users').doc(tx.userId), {
          premiumPlan: plan.planId,
          premiumStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    return res.status(200).send('OK');
  } catch (e) {
    console.error('paystackWebhook error:', e);
    return res.status(500).send('Internal error');
  }
});

// ────────────────────────────────────────────────────────────────────────
// verifyPaystackTransaction — safety-net check the client calls right
// after returning from the checkout WebView, in case the webhook hasn't
// landed yet. Never trusts the client's own memory of the transaction;
// always re-checks against Paystack and Firestore.
// ────────────────────────────────────────────────────────────────────────
exports.verifyPaystackTransaction = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');
  try {
    const decoded = await verifyAuth(req);
    const { reference } = req.body || {};
    if (!reference) return res.status(400).json({ error: 'reference is required' });

    const txSnap = await db.collection('transactions').doc(reference).get();
    if (!txSnap.exists) return res.status(404).json({ error: 'Transaction not found' });
    const tx = txSnap.data();
    if (tx.userId !== decoded.uid) return res.status(403).json({ error: 'Not your transaction' });

    if (tx.status === 'success') {
      return res.status(200).json({ status: 'success', type: tx.type, metadata: tx.metadata });
    }

    const paystackRes = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
      headers: { Authorization: `Bearer ${paystackSecretKey()}` },
    });
    const paystackData = await paystackRes.json();

    if (paystackData.data && paystackData.data.status === 'success') {
      // Let the same idempotent path the webhook uses do the actual
      // granting, by re-posting the same shape of event to ourselves is
      // unnecessary complexity here — instead just mark pending and let
      // the real webhook (which Paystack retries independently) finish
      // the grant. We report "pending" rather than fabricating success.
      return res.status(200).json({ status: 'pending', type: tx.type, metadata: tx.metadata });
    }

    return res.status(200).json({ status: paystackData.data ? paystackData.data.status : 'pending' });
  } catch (e) {
    console.error('verifyPaystackTransaction error:', e);
    return res.status(401).json({ error: e.message || 'Unauthorized' });
  }
});

// ────────────────────────────────────────────────────────────────────────
// reviewVerificationRequest — the ONLY way a verification_requests
// document can move to 'approved'/'rejected', and the ONLY way a user's
// or listing's verificationStatus can become 'approved'. Requires the
// caller's ID token to carry a custom claim `admin: true` or
// `reviewer: true` — see setAdminOrReviewerClaim below for how that claim
// gets set.
// ────────────────────────────────────────────────────────────────────────
exports.reviewVerificationRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth || !(context.auth.token.admin || context.auth.token.reviewer)) {
    throw new functions.https.HttpsError('permission-denied', 'Reviewer or admin privileges required.');
  }

  const { requestId, decision, reason, expiresInDays } = data;
  if (!requestId || !['approved', 'rejected', 'needs_changes'].includes(decision)) {
    throw new functions.https.HttpsError('invalid-argument', 'requestId and a valid decision are required.');
  }

  const reqRef = db.collection('verification_requests').doc(requestId);
  const reqSnap = await reqRef.get();
  if (!reqSnap.exists) throw new functions.https.HttpsError('not-found', 'Request not found.');
  const request = reqSnap.data();

  const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
  const auditEntry = {
    by: context.auth.uid,
    action: decision,
    at: new Date().toISOString(),
    note: reason || null,
  };

  const batch = db.batch();
  batch.update(reqRef, {
    status: decision,
    reviewerId: context.auth.uid,
    reviewedAt,
    rejectionReason: reason || null,
    auditHistory: admin.firestore.FieldValue.arrayUnion(auditEntry),
    updatedAt: reviewedAt,
  });

  const userRef = db.collection('users').doc(request.applicantId);
  if (decision === 'approved') {
    const expiresAt = new Date(Date.now() + (expiresInDays || 365) * 24 * 60 * 60 * 1000);
    batch.update(reqRef, { expiresAt: admin.firestore.Timestamp.fromDate(expiresAt) });
    batch.update(userRef, {
      verificationStatus: 'approved',
      verificationType: request.requestType,
      verifiedAt: reviewedAt,
      verifiedBy: context.auth.uid,
      verificationExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      isVerified: true,
      updatedAt: reviewedAt,
    });
    // Property-specific verification also verifies that one listing —
    // NOT every listing the agent owns, per the review's explicit
    // "identity verification alone should not automatically imply every
    // listing is verified."
    if (request.requestType === 'property' && request.listingId) {
      batch.update(db.collection('listings').doc(request.listingId), {
        verificationStatus: 'approved',
        verificationType: 'property',
        verifiedAt: reviewedAt,
        verifiedBy: context.auth.uid,
        verificationExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        isVerified: true,
        updatedAt: reviewedAt,
      });
    }
  } else {
    batch.update(userRef, {
      verificationStatus: decision, // 'rejected' | 'needs_changes'
      updatedAt: reviewedAt,
    });
  }

  await batch.commit();
  return { success: true };
});

// ────────────────────────────────────────────────────────────────────────
// getReviewDocumentUrl — the only way a reviewer's client ever sees an
// actual URL for a private verification document. Signed for 10 minutes.
// Regular users get permission-denied.
// ────────────────────────────────────────────────────────────────────────
exports.getReviewDocumentUrl = functions.https.onCall(async (data, context) => {
  if (!context.auth || !(context.auth.token.admin || context.auth.token.reviewer)) {
    throw new functions.https.HttpsError('permission-denied', 'Reviewer or admin privileges required.');
  }
  const { storagePath } = data;
  if (!storagePath || !storagePath.startsWith('verification/')) {
    throw new functions.https.HttpsError('invalid-argument', 'A valid verification/ storage path is required.');
  }
  const [url] = await storage.bucket().file(storagePath).getSignedUrl({
    action: 'read',
    expires: Date.now() + 10 * 60 * 1000,
  });
  return { url };
});

// ────────────────────────────────────────────────────────────────────────
// checkSavedSearches — Phase 3. Runs on a schedule, finds listings
// created since the last run, and matches them against every saved
// search with alertsEnabled. A match creates a real `notifications`
// document, reusing the pipeline notifications_screen.dart already reads
// from — no new delivery mechanism needed. Firestore doesn't support the
// kind of multi-field OR query saved-search matching needs, so this pulls
// the (small, recent) candidate set and matches in memory — reasonable at
// current scale; worth revisiting if new-listing volume grows a lot.
// ────────────────────────────────────────────────────────────────────────
function listingMatchesSearch(listing, search) {
  if (search.category && listing.category !== search.category) return false;
  if (search.propertyType && listing.propertyType !== search.propertyType) return false;
  if (search.area && listing.location && listing.location.area !== search.area) return false;
  if (search.minBedrooms != null && (listing.bedrooms || 0) < search.minBedrooms) return false;
  if (search.minPrice != null && (listing.price || 0) < search.minPrice) return false;
  if (search.maxPrice != null && (listing.price || 0) > search.maxPrice) return false;
  if (search.query) {
    const q = String(search.query).toLowerCase();
    const haystack = `${listing.title || ''} ${listing.description || ''} ${(listing.location || {}).area || ''}`.toLowerCase();
    if (!haystack.includes(q)) return false;
  }
  return true;
}

exports.checkSavedSearches = functions.pubsub.schedule('every 15 minutes').onRun(async () => {
  const cursorRef = db.collection('system').doc('savedSearchCursor');
  const cursorSnap = await cursorRef.get();
  const lastCheckedAt = cursorSnap.exists && cursorSnap.data().lastCheckedAt
    ? cursorSnap.data().lastCheckedAt
    : admin.firestore.Timestamp.fromMillis(Date.now() - 20 * 60 * 1000);
  const now = admin.firestore.Timestamp.now();

  const newListingsSnap = await db.collection('listings')
    .where('status', '==', 'active')
    .where('createdAt', '>', lastCheckedAt)
    .get();

  if (newListingsSnap.empty) {
    await cursorRef.set({ lastCheckedAt: now }, { merge: true });
    console.log('checkSavedSearches: no new listings since last run.');
    return null;
  }

  const searchesSnap = await db.collection('saved_searches')
    .where('alertsEnabled', '==', true)
    .get();

  if (searchesSnap.empty) {
    await cursorRef.set({ lastCheckedAt: now }, { merge: true });
    return null;
  }

  const newListings = newListingsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const batch = db.batch();
  let notifCount = 0;

  for (const searchDoc of searchesSnap.docs) {
    const search = searchDoc.data();
    const matches = newListings.filter((l) => listingMatchesSearch(l, search));
    if (matches.length === 0) continue;

    for (const listing of matches.slice(0, 5)) { // cap per-run notifications per search
      const notifRef = db.collection('notifications').doc();
      batch.set(notifRef, {
        userId: search.userId,
        type: 'saved_search_match',
        title: `New match: ${search.label}`,
        body: listing.title || 'A new listing matches your saved search',
        route: `/listing/${listing.id}`,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      notifCount++;
    }
    batch.update(searchDoc.ref, { lastMatchedAt: admin.firestore.FieldValue.serverTimestamp() });
  }

  batch.set(cursorRef, { lastCheckedAt: now }, { merge: true });
  await batch.commit();
  console.log(`checkSavedSearches: created ${notifCount} notifications from ${newListings.length} new listings.`);
  return null;
});

// ────────────────────────────────────────────────────────────────────────
// setAdminOrReviewerClaim — bootstraps/administers custom claims. Guarded
// so a user can NEVER grant themselves admin — "users cannot create
// themselves as administrators." The very first admin must be set once,
// manually, via the Firebase Admin SDK from a trusted machine (see
// PHASE1_README.md) — after that, existing admins can promote others
// through this function.
// ────────────────────────────────────────────────────────────────────────
exports.setAdminOrReviewerClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only an existing admin can grant this claim.');
  }
  const { uid, admin: grantAdmin, reviewer: grantReviewer } = data;
  if (!uid) throw new functions.https.HttpsError('invalid-argument', 'uid is required.');

  await auth.setCustomUserClaims(uid, {
    admin: !!grantAdmin,
    reviewer: !!grantReviewer || !!grantAdmin,
  });
  return { success: true };
});