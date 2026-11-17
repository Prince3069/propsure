/**
 * Payments — Paystack initialise, webhook, verify and reconcile.
 *
 * Rules this module enforces (the Flutter app is never trusted for any):
 *  - The amount charged and the entitlement granted come from the server
 *    catalog (lib/config.js), never from the request.
 *  - The callback URL is a fixed server value; a client value is ignored.
 *  - A grant needs: valid HMAC signature (constant-time compare) OR a fresh
 *    Paystack verify call, AND status === 'success', AND currency === 'NGN',
 *    AND exact amount, reference and customer-email match, AND the metadata
 *    uid equals the user who started the transaction.
 *  - A boost re-checks listing ownership/status AT GRANT TIME. If the
 *    listing is no longer eligible the money is NOT silently swallowed: the
 *    transaction becomes `paid_unfulfilled` for manual refund/resolution.
 *  - Grants are idempotent (one Firestore transaction, status guard), so a
 *    duplicated webhook, a verify call and a reconcile run can all race
 *    safely.
 *  - This is a fixed-duration access pass, NOT a recurring subscription.
 */
const functions = require('firebase-functions/v1');
const crypto = require('crypto');
const fetch = require('node-fetch');
const { admin, db, FieldValue, Timestamp, DAY_MS } = require('./admin');
const { planCatalog, PAYSTACK_CALLBACK_URL, boostCatalogName } = require('./config');

function paystackSecretKey() {
  const key = process.env.PAYSTACK_SECRET_KEY;
  if (!key) throw new Error('PAYSTACK_SECRET_KEY is not set. Create functions/.env — see DEPLOY.md.');
  return key;
}

async function verifyAuth(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    const err = new Error('Missing Authorization bearer token.');
    err.status = 401;
    throw err;
  }
  try {
    return await admin.auth().verifyIdToken(token);
  } catch (_) {
    const err = new Error('Invalid or expired sign-in. Please sign in again.');
    err.status = 401;
    throw err;
  }
}

/** Constant-time hex compare. */
function safeEqualHex(a, b) {
  try {
    const ba = Buffer.from(String(a || ''), 'hex');
    const bb = Buffer.from(String(b || ''), 'hex');
    if (ba.length === 0 || ba.length !== bb.length) return false;
    return crypto.timingSafeEqual(ba, bb);
  } catch (_) {
    return false;
  }
}

function signatureIsValid(rawBody, signature) {
  const expected = crypto.createHmac('sha512', paystackSecretKey()).update(rawBody).digest('hex');
  return safeEqualHex(signature, expected);
}

/**
 * Pure check: does the gateway's view of a charge match what we created?
 * Returns null when it matches, or a human-readable reason when it does not.
 */
function chargeMismatch(tx, data) {
  if (!data) return 'No gateway data.';
  if (data.status !== 'success') return `Gateway status is ${data.status}.`;
  if (data.reference !== tx.reference) return 'Reference mismatch.';
  if (String(data.currency || '').toUpperCase() !== 'NGN') return `Currency is ${data.currency}, expected NGN.`;
  if (data.amount !== tx.amountKobo) return `Amount mismatch: expected ${tx.amountKobo}, got ${data.amount}.`;
  const customer = data.customer && data.customer.email ? String(data.customer.email).toLowerCase() : '';
  if (!customer || customer !== String(tx.userEmail || '').toLowerCase()) return 'Customer email mismatch.';
  const metaUid = data.metadata && data.metadata.uid;
  if (!metaUid || metaUid !== tx.userId) return 'Metadata user mismatch.';
  return null;
}

/**
 * Idempotently grants the entitlement for a transaction. Safe to call from
 * the webhook, the verify endpoint and the reconcile job at the same time.
 * `data` must be Paystack charge data (from a signed webhook OR a verify call).
 */
async function grantFromGatewayData(reference, data) {
  const txRef = db.collection('transactions').doc(reference);
  return db.runTransaction(async (t) => {
    const txSnap = await t.get(txRef);
    if (!txSnap.exists) return { result: 'unknown_reference' };
    const tx = txSnap.data();
    if (tx.status === 'success') return { result: 'already_granted', tx };
    if (tx.status === 'paid_unfulfilled') return { result: 'paid_unfulfilled', tx };

    const mismatch = chargeMismatch(tx, data);
    if (mismatch) {
      // A non-success gateway status is not a failure of OUR check.
      if (data && data.status && data.status !== 'success') {
        return { result: 'not_successful', tx };
      }
      t.update(txRef, { status: 'failed', failureReason: mismatch, updatedAt: FieldValue.serverTimestamp() });
      return { result: 'rejected', reason: mismatch };
    }

    const plan = planCatalog()[tx.planId];
    if (!plan) {
      t.update(txRef, { status: 'paid_unfulfilled', failureReason: 'Plan no longer exists.', updatedAt: FieldValue.serverTimestamp() });
      return { result: 'paid_unfulfilled' };
    }

    const common = {
      webhookEventId: data.id ? String(data.id) : null,
      paystackTransactionId: data.id || null,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (plan.type === 'boost') {
      const listingId = tx.metadata && tx.metadata.listingId;
      const listingRef = db.collection('listings').doc(String(listingId || '_'));
      const listingSnap = await t.get(listingRef);
      const listing = listingSnap.exists ? listingSnap.data() : null;
      // Re-authorise at grant time: still owned by the payer, still live.
      if (!listing || listing.agentId !== tx.userId || listing.status !== 'active') {
        t.update(txRef, {
          ...common,
          status: 'paid_unfulfilled',
          failureReason: 'Listing was not eligible for promotion when payment completed.',
        });
        return { result: 'paid_unfulfilled' };
      }
      const currentEnd = listing.featuredUntil ? listing.featuredUntil.toMillis() : 0;
      const start = Math.max(Date.now(), currentEnd);
      t.update(listingRef, {
        isFeatured: true,
        featuredUntil: Timestamp.fromMillis(start + plan.boostDays * DAY_MS),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else if (plan.type === 'premium') {
      const userRef = db.collection('users').doc(tx.userId);
      const userSnap = await t.get(userRef);
      const user = userSnap.exists ? userSnap.data() : {};
      const currentEnd = user.premiumExpiresAt ? user.premiumExpiresAt.toMillis() : 0;
      const start = Math.max(Date.now(), currentEnd);
      t.update(userRef, {
        premiumPlan: plan.planId,
        premiumStartedAt: user.premiumStartedAt || FieldValue.serverTimestamp(),
        premiumExpiresAt: Timestamp.fromMillis(start + plan.durationDays * DAY_MS),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    t.update(txRef, { ...common, status: 'success', grantedAt: FieldValue.serverTimestamp() });
    return { result: 'granted' };
  });
}

async function fetchGatewayCharge(reference) {
  const res = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
    headers: { Authorization: `Bearer ${paystackSecretKey()}` },
  });
  const body = await res.json();
  return body && body.data ? body.data : null;
}

// ── initializePaystackTransaction ─────────────────────────────────────────
exports.initializePaystackTransaction = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');
  try {
    const decoded = await verifyAuth(req);
    const uid = decoded.uid;
    const { planId, metadata = {} } = req.body || {};

    const plan = planCatalog()[planId];
    if (!plan || plan.hiddenUntilConfirmed) return res.status(400).json({ error: 'That plan is not available.' });

    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists) return res.status(403).json({ error: 'Create your profile before paying.' });
    const user = userSnap.data();
    if (!['agent', 'landlord'].includes(user.role)) {
      return res.status(403).json({ error: 'Agent tools are for agents and landlords who list property.' });
    }

    const cleanMeta = {};
    if (plan.type === 'boost') {
      const listingId = String(metadata.listingId || '');
      if (!listingId) return res.status(400).json({ error: 'Choose a listing to promote.' });
      const listingSnap = await db.collection('listings').doc(listingId).get();
      if (!listingSnap.exists) return res.status(404).json({ error: 'Listing not found.' });
      const listing = listingSnap.data();
      if (listing.agentId !== uid) return res.status(403).json({ error: 'You can only promote your own listing.' });
      if (listing.status !== 'active') return res.status(409).json({ error: 'Only live listings can be promoted.' });
      if (listing.safetyHold) return res.status(409).json({ error: 'This listing is under review and cannot be promoted right now.' });
      cleanMeta.listingId = listingId;
    }

    const email = decoded.email || user.email;
    if (!email) {
      return res.status(400).json({ error: 'Add an email address to your profile so we can send your receipt.' });
    }

    const reference = `propsure_${crypto.randomBytes(16).toString('hex')}`;
    await db.collection('transactions').doc(reference).set({
      reference,
      userId: uid,
      userEmail: email,
      planId,
      type: plan.type,
      amountKobo: plan.amountKobo,
      amountNGN: plan.amountKobo / 100,
      currency: 'NGN',
      metadata: cleanMeta,
      catalog: boostCatalogName(),
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const psRes = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: { Authorization: `Bearer ${paystackSecretKey()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        amount: plan.amountKobo,
        currency: 'NGN',
        reference,
        callback_url: PAYSTACK_CALLBACK_URL,
        metadata: { ...cleanMeta, planId, uid },
      }),
    });
    const ps = await psRes.json();
    if (!ps.status) {
      await db.collection('transactions').doc(reference).update({ status: 'failed', failureReason: 'Initialise rejected.' });
      return res.status(502).json({ error: 'The payment provider could not start this payment. Please try again.' });
    }
    return res.status(200).json({ authorization_url: ps.data.authorization_url, reference });
  } catch (e) {
    console.error('initializePaystackTransaction error:', e);
    return res.status(e.status || 500).json({ error: e.status === 401 ? e.message : 'Could not start payment. Please try again.' });
  }
});

// ── paystackWebhook ───────────────────────────────────────────────────────
exports.paystackWebhook = functions.https.onRequest(async (req, res) => {
  if (!signatureIsValid(req.rawBody, req.headers['x-paystack-signature'])) {
    console.warn('paystackWebhook: invalid signature.');
    return res.status(401).send('Invalid signature');
  }
  const event = req.body || {};
  if (event.event !== 'charge.success') return res.status(200).send('Ignored');
  try {
    const out = await grantFromGatewayData(event.data && event.data.reference, event.data);
    console.log('paystackWebhook:', event.data && event.data.reference, out.result);
    return res.status(200).send('OK');
  } catch (e) {
    console.error('paystackWebhook error:', e);
    return res.status(500).send('Internal error'); // Paystack will retry.
  }
});

// ── verifyPaystackTransaction ─────────────────────────────────────────────
// Called by the app after checkout. Asks Paystack directly and runs the SAME
// idempotent grant as the webhook, so a lost webhook never strands a payment.
exports.verifyPaystackTransaction = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');
  try {
    const decoded = await verifyAuth(req);
    const { reference } = req.body || {};
    if (!reference) return res.status(400).json({ error: 'reference is required' });

    const txSnap = await db.collection('transactions').doc(String(reference)).get();
    if (!txSnap.exists) return res.status(404).json({ error: 'Transaction not found' });
    const tx = txSnap.data();
    if (tx.userId !== decoded.uid) return res.status(403).json({ error: 'Not your transaction' });
    if (tx.status === 'success') return res.status(200).json({ status: 'success', type: tx.type, metadata: tx.metadata });
    if (tx.status === 'paid_unfulfilled') return res.status(200).json({ status: 'paid_unfulfilled', type: tx.type, metadata: tx.metadata });

    const charge = await fetchGatewayCharge(reference);
    if (!charge) return res.status(200).json({ status: 'pending' });
    if (charge.status === 'success') {
      const out = await grantFromGatewayData(reference, charge);
      const status = out.result === 'granted' || out.result === 'already_granted' ? 'success'
        : out.result === 'paid_unfulfilled' ? 'paid_unfulfilled' : 'failed';
      return res.status(200).json({ status, type: tx.type, metadata: tx.metadata });
    }
    if (charge.status === 'failed' || charge.status === 'abandoned') {
      await db.collection('transactions').doc(String(reference)).update({
        status: charge.status, updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return res.status(200).json({ status: charge.status === 'failed' ? 'failed' : 'pending', type: tx.type, metadata: tx.metadata });
  } catch (e) {
    console.error('verifyPaystackTransaction error:', e);
    return res.status(e.status || 500).json({ error: e.status === 401 ? e.message : 'Could not confirm payment. Please try again.' });
  }
});

// ── reconcilePendingTransactions ──────────────────────────────────────────
// Catches payments whose webhook never arrived.
exports.reconcilePendingTransactions = functions.pubsub.schedule('every 30 minutes').onRun(async () => {
  const tenMinAgo = Timestamp.fromMillis(Date.now() - 10 * 60 * 1000);
  const dayAgo = Timestamp.fromMillis(Date.now() - DAY_MS);
  const snap = await db.collection('transactions')
    .where('status', '==', 'pending')
    .where('createdAt', '<', tenMinAgo)
    .limit(100)
    .get();
  let granted = 0;
  for (const doc of snap.docs) {
    try {
      const charge = await fetchGatewayCharge(doc.id);
      if (charge && charge.status === 'success') {
        const out = await grantFromGatewayData(doc.id, charge);
        if (out.result === 'granted') granted++;
      } else if (doc.data().createdAt < dayAgo) {
        await doc.ref.update({ status: 'abandoned', updatedAt: FieldValue.serverTimestamp() });
      }
    } catch (e) {
      console.error('reconcile error for', doc.id, e);
    }
  }
  console.log(`reconcilePendingTransactions: checked ${snap.size}, granted ${granted}.`);
  return null;
});

// ── getPricing ────────────────────────────────────────────────────────────
// What the app is allowed to DISPLAY. Amounts here are what will be charged.
exports.getPricing = functions.https.onCall(async () => {
  const catalog = planCatalog();
  const boosts = [];
  let proMonthly = null;
  for (const [id, p] of Object.entries(catalog)) {
    if (p.hiddenUntilConfirmed) continue;
    if (p.type === 'boost') boosts.push({ id, amountNGN: p.amountKobo / 100, days: p.boostDays });
    if (id === 'agent_pro_monthly') proMonthly = { id, amountNGN: p.amountKobo / 100, days: p.durationDays };
  }
  boosts.sort((a, b) => a.days - b.days);
  const { activeListingLimit } = require('./config');
  return {
    boosts,
    agentPro: proMonthly,
    limits: { free: activeListingLimit(false), pro: activeListingLimit(true) },
    recurring: false,
  };
});

module.exports.chargeMismatch = chargeMismatch;
module.exports.__grant = grantFromGatewayData;
module.exports.safeEqualHex = safeEqualHex;
