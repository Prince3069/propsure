/**
 * Check before you pay.
 *
 * A renter pastes the bank and account number an agent gave them. We ask
 * Paystack (Resolve Account Number) for the name on that account and compare
 * it with the agent's name on Propsure. We report what the bank says and
 * whether the names match. We never say a person or home is "safe".
 *
 * Paystack's resolve endpoint needs a live secret key in production; in test
 * mode it may only resolve test accounts, which the app reports honestly as
 * "could not look up".
 */
const functions = require('firebase-functions/v1');
const fetch = require('node-fetch');
const { db, FieldValue } = require('./admin');

const PAYSTACK = 'https://api.paystack.co';
const DAILY_LIMIT = 10;

function secretKey() {
  const key = process.env.PAYSTACK_SECRET_KEY;
  if (!key) throw new functions.https.HttpsError('failed-precondition', 'This check is not available right now.');
  return key;
}

async function paystackGet(path) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const res = await fetch(`${PAYSTACK}${path}`, { headers: { Authorization: `Bearer ${secretKey()}` }, signal: controller.signal });
    let body = null;
    try { body = await res.json(); } catch (_) { body = null; }
    return { status: res.status, body };
  } catch (e) {
    throw new functions.https.HttpsError('unavailable', 'We could not reach the bank lookup. Please try again in a moment.');
  } finally {
    clearTimeout(timer);
  }
}

let bankCache = { at: 0, list: [] };

exports.listBanks = functions.https.onCall(async (_data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  if (bankCache.list.length && Date.now() - bankCache.at < 12 * 60 * 60 * 1000) return { banks: bankCache.list };
  const { status, body } = await paystackGet('/bank?country=nigeria&perPage=200');
  if (status !== 200 || !body || !Array.isArray(body.data)) {
    throw new functions.https.HttpsError('unavailable', 'We could not load the bank list. Please try again.');
  }
  const list = body.data
    .filter((b) => b && b.active !== false && !b.is_deleted && b.code && b.name && (!b.type || b.type === 'nuban'))
    .map((b) => ({ name: String(b.name), code: String(b.code) }))
    .sort((a, b) => a.name.localeCompare(b.name));
  bankCache = { at: Date.now(), list };
  return { banks: list };
});

const SUFFIX_WORDS = new Set(['LTD', 'LIMITED', 'NIG', 'NIGERIA', 'ENTERPRISE', 'ENTERPRISES', 'CO', 'COMPANY', 'PLC', 'RC', 'AND', 'THE', 'MR', 'MRS', 'MISS', 'MS', 'DR', 'CHIEF', 'ENGR']);

function tokens(s) {
  return String(s || '')
    .toUpperCase()
    .replace(/[^A-Z0-9 ]+/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 1 && !SUFFIX_WORDS.has(t));
}

/** True when every word of the shorter name appears in the longer one (min 2 words). */
function namesMatch(a, b) {
  const ta = tokens(a);
  const tb = tokens(b);
  if (ta.length < 2 || tb.length < 2) {
    return ta.length > 0 && tb.length > 0 && ta.join(' ') === tb.join(' ');
  }
  const [small, big] = ta.length <= tb.length ? [ta, tb] : [tb, ta];
  const set = new Set(big);
  return small.every((t) => set.has(t));
}

exports.checkAccountName = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  const uid = context.auth.uid;
  const { listingId, bankCode, accountNumber } = data || {};
  const acct = String(accountNumber || '').replace(/\s+/g, '');
  const bank = String(bankCode || '');
  if (!/^\d{10}$/.test(acct)) throw new functions.https.HttpsError('invalid-argument', 'Enter the 10-digit account number.');
  if (!/^\d{3,8}$/.test(bank)) throw new functions.https.HttpsError('invalid-argument', 'Choose a bank.');

  // A few checks a day per person, so this cannot be used to probe accounts.
  const day = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const counterRef = db.collection('system').doc(`accountcheck_${uid}_${day}`);
  const used = await db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const n = snap.exists ? Number(snap.data().count || 0) : 0;
    if (n >= DAILY_LIMIT) return -1;
    tx.set(counterRef, { count: n + 1, uid, day }, { merge: true });
    return n + 1;
  });
  if (used < 0) throw new functions.https.HttpsError('resource-exhausted', 'You have used today\'s account checks. Please try again tomorrow.');

  const { status, body } = await paystackGet(`/bank/resolve?account_number=${encodeURIComponent(acct)}&bank_code=${encodeURIComponent(bank)}`);
  if (status === 422 || status === 404) {
    throw new functions.https.HttpsError('not-found', 'We could not find that account. Check the bank and the number with the agent.');
  }
  if (status !== 200 || !body || !body.status || !body.data || !body.data.account_name) {
    throw new functions.https.HttpsError('unavailable', 'We could not look up this account right now. Please try again later.');
  }
  const accountName = String(body.data.account_name).trim();

  let verdict = 'unknown';
  let agentName = null;
  let agencyName = null;
  let agentIdChecked = false;
  let matchedOn = null;
  let agentId = null;
  if (listingId) {
    const l = await db.collection('listings').doc(String(listingId)).get();
    if (l.exists) {
      agentId = l.data().agentId;
      const u = agentId ? await db.collection('users').doc(agentId).get() : null;
      if (u && u.exists) {
        const d = u.data();
        agentName = d.name || null;
        agencyName = d.agencyName || null;
        agentIdChecked = d.verificationStatus === 'approved' && !!d.verificationExpiresAt && d.verificationExpiresAt.toMillis() > Date.now();
        if (agentName && namesMatch(accountName, agentName)) { verdict = 'match'; matchedOn = 'name'; }
        else if (agencyName && namesMatch(accountName, agencyName)) { verdict = 'match'; matchedOn = 'agency'; }
        else verdict = 'different';
      }
    }
  }

  await db.collection('account_checks').add({
    userId: uid, listingId: listingId || null, agentId, bankCode: bank, last4: acct.slice(-4), verdict, createdAt: FieldValue.serverTimestamp(),
  });
  return { accountName, verdict, matchedOn, agentName, agencyName, agentIdChecked };
});

module.exports.namesMatch = namesMatch;
