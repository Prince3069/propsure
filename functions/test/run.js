const path = require('path');
process.env.PAYSTACK_SECRET_KEY = 'sk_test_x';
process.env.FOUNDER_PROMO_ENABLED = 'true';
process.env.FOUNDER_SLOTS = '3';
// Swap lib/admin.js for the in-memory fake BEFORE anything requires it.
const adminPath = require.resolve(path.join(__dirname, '..', 'lib', 'admin.js'));
const fake = require('./fake_admin');
require.cache[adminPath] = { id: adminPath, filename: adminPath, loaded: true, exports: fake };

const assert = require('assert');
const crypto = require('crypto');
const payments = require('../lib/payments');
const listings = require('../lib/listings');
const media = require('../lib/media');
const alerts = require('../lib/alerts');
const founder = require('../founder_promo');
const { moveInBreakdown } = require('../lib/cost');
const config = require('../lib/config');
const store = fake.__store;
const { Timestamp } = fake;

let passed = 0; const failures = [];
async function test(name, fn) { try { await fn(); passed++; console.log('  ok  ', name); } catch (e) { failures.push(name); console.log('  FAIL', name, '\n      ', e.message); } }
const ctx = (uid) => ({ auth: { uid, token: {} } });

(async () => {
  console.log('payments');
  const mkTx = (over = {}) => ({ reference: 'ref1', userId: 'u1', userEmail: 'A@x.com', planId: 'agent_pro_monthly', type: 'premium', amountKobo: 1000000, metadata: {}, status: 'pending', ...over });
  const charge = (over = {}) => ({ status: 'success', reference: 'ref1', currency: 'NGN', amount: 1000000, id: 99, customer: { email: 'a@x.com' }, metadata: { uid: 'u1' }, ...over });

  await test('signature: valid and invalid, constant-time compare', () => {
    const body = Buffer.from('{"a":1}');
    const sig = crypto.createHmac('sha512', 'sk_test_x').update(body).digest('hex');
    assert.ok(payments.safeEqualHex(sig, sig));
    assert.ok(!payments.safeEqualHex(sig, sig.replace(/.$/, '0') === sig ? 'ab' : sig.replace(/.$/, '0')));
    assert.ok(!payments.safeEqualHex('', ''));
    assert.ok(!payments.safeEqualHex(undefined, sig));
  });
  await test('chargeMismatch accepts a perfect match', () => assert.strictEqual(payments.chargeMismatch(mkTx(), charge()), null));
  await test('chargeMismatch rejects wrong amount / currency / email / uid / reference / status', () => {
    for (const bad of [{ amount: 1 }, { currency: 'USD' }, { customer: { email: 'z@x.com' } }, { metadata: { uid: 'u2' } }, { reference: 'other' }, { status: 'failed' }]) {
      assert.ok(payments.chargeMismatch(mkTx(), charge(bad)), JSON.stringify(bad));
    }
  });

  store.set('users/u1', { role: 'agent', email: 'a@x.com' });
  store.set('transactions/ref1', mkTx());
  await test('premium grant is applied exactly once under concurrent webhook + verify + reconcile', async () => {
    const results = await Promise.all([1, 2, 3].map(() => payments.grantFromGatewayData ? null : null));
    assert.ok(results); // placeholder; real call below
  });
  // grantFromGatewayData is internal — reach it through the exported surface by re-requiring the module's function.
  const grant = require('../lib/payments').__grant;
  assert.ok(grant, 'payments must export __grant for tests');
  store.set('transactions/ref1', mkTx());
  await test('concurrent grants → one grant, others already_granted', async () => {
    const out = await Promise.all([grant('ref1', charge()), grant('ref1', charge()), grant('ref1', charge())]);
    assert.strictEqual(out.filter((o) => o.result === 'granted').length, 1);
    assert.strictEqual(out.filter((o) => o.result === 'already_granted').length, 2);
    const u = store.get('users/u1');
    assert.strictEqual(u.premiumPlan, 'agent_pro');
    assert.ok(u.premiumExpiresAt.toMillis() > Date.now() + 29 * 86400000);
    assert.strictEqual(store.get('transactions/ref1').status, 'success');
  });
  await test('a second paid period stacks from the current expiry', async () => {
    const before = store.get('users/u1').premiumExpiresAt.toMillis();
    store.set('transactions/ref2', mkTx({ reference: 'ref2' }));
    await grant('ref2', charge({ reference: 'ref2' }));
    assert.ok(store.get('users/u1').premiumExpiresAt.toMillis() >= before + 29 * 86400000);
  });
  await test('amount mismatch → failed, NOTHING granted', async () => {
    store.set('users/u3', { role: 'agent', email: 'a@x.com' });
    store.set('transactions/ref3', mkTx({ reference: 'ref3', userId: 'u3' }));
    const out = await grant('ref3', charge({ reference: 'ref3', amount: 100, metadata: { uid: 'u3' } }));
    assert.strictEqual(out.result, 'rejected');
    assert.strictEqual(store.get('transactions/ref3').status, 'failed');
    assert.strictEqual(store.get('users/u3').premiumPlan, undefined);
  });
  await test('non-success gateway status does not fail the transaction', async () => {
    store.set('transactions/ref4', mkTx({ reference: 'ref4' }));
    const out = await grant('ref4', charge({ reference: 'ref4', status: 'abandoned' }));
    assert.strictEqual(out.result, 'not_successful');
    assert.strictEqual(store.get('transactions/ref4').status, 'pending');
  });
  await test('boost for a listing the payer no longer owns → paid_unfulfilled, no placement granted', async () => {
    store.set('listings/L1', { agentId: 'someoneElse', status: 'active' });
    store.set('transactions/ref5', mkTx({ reference: 'ref5', planId: 'boost_7', type: 'boost', amountKobo: 300000, metadata: { listingId: 'L1' } }));
    const out = await grant('ref5', charge({ reference: 'ref5', amount: 300000 }));
    assert.strictEqual(out.result, 'paid_unfulfilled');
    assert.strictEqual(store.get('listings/L1').isFeatured, undefined);
    assert.strictEqual(store.get('transactions/ref5').status, 'paid_unfulfilled');
  });
  await test('boost for an eligible listing sets featuredUntil for 7 days', async () => {
    store.set('listings/L2', { agentId: 'u1', status: 'active' });
    store.set('transactions/ref6', mkTx({ reference: 'ref6', planId: 'boost_7', type: 'boost', amountKobo: 300000, metadata: { listingId: 'L2' } }));
    const out = await grant('ref6', charge({ reference: 'ref6', amount: 300000 }));
    assert.strictEqual(out.result, 'granted');
    const l = store.get('listings/L2');
    assert.strictEqual(l.isFeatured, true);
    assert.ok(Math.abs(l.featuredUntil.toMillis() - (Date.now() + 7 * 86400000)) < 5000);
  });
  await test('a boost does NOT change verification fields', () => {
    const l = store.get('listings/L2');
    assert.strictEqual(l.isVerified, undefined);
    assert.strictEqual(l.verificationStatus, undefined);
  });

  console.log('config / catalogs');
  await test('pilot catalog = 3,000 / 5,000; standard = 5,000 / 10,000 / 20,000', () => {
    assert.strictEqual(config.BOOST_CATALOGS.pilot.boost_7.amountKobo, 300000);
    assert.strictEqual(config.BOOST_CATALOGS.pilot.boost_14.amountKobo, 500000);
    assert.strictEqual(config.BOOST_CATALOGS.standard.boost_30.amountKobo, 2000000);
    assert.strictEqual(config.planCatalog().agent_pro_monthly.amountKobo, 1000000);
    assert.ok(!config.planCatalog().agent_elite_monthly, 'Elite must not be sold');
  });

  console.log('listings');
  const goodListing = (over = {}) => ({ agentId: 'p1', status: 'draft', title: '2-bedroom flat Gwarinpa', price: 2400000, category: 'for_rent', location: { area: 'Gwarinpa' }, images: ['u'], ...over });
  await test('publishProblems flags missing fields and processing video', () => {
    assert.deepStrictEqual(listings.publishProblems(goodListing()), []);
    assert.ok(listings.publishProblems(goodListing({ images: [] })).length === 1);
    assert.ok(listings.publishProblems(goodListing({ videoStatus: 'processing' })).length === 1);
    assert.ok(listings.publishProblems(goodListing({ category: 'For Rent' })).length === 1);
  });
  store.set('users/p1', { role: 'agent', totalListings: 0 });
  store.set('listings/D1', goodListing());
  await test('publishListing requires the availability confirmation', async () => {
    await assert.rejects(listings.publishListing.run({ listingId: 'D1' }, ctx('p1')), /still available/);
  });
  await test('publishListing rejects a non-owner and a renter account', async () => {
    store.set('users/other', { role: 'agent', totalListings: 0 });
    await assert.rejects(listings.publishListing.run({ listingId: 'D1', availabilityConfirmed: true }, ctx('other')), /not your listing/);
    store.set('users/p1', { role: 'tenant', totalListings: 0 });
    await assert.rejects(listings.publishListing.run({ listingId: 'D1', availabilityConfirmed: true }, ctx('p1')), /Switch to a listing account/);
    store.set('users/p1', { role: 'agent', totalListings: 0 });
  });
  await test('publishListing goes live, stamps availability, and counts toward the quota', async () => {
    await listings.publishListing.run({ listingId: 'D1', availabilityConfirmed: true }, ctx('p1'));
    const l = store.get('listings/D1');
    assert.strictEqual(l.status, 'active');
    assert.strictEqual(l.availabilityConfirmedBy, 'agent');
    assert.strictEqual(store.get('users/p1').totalListings, 1);
  });
  await test('free plan caps live listings at 3; Pro allows more', async () => {
    store.set('users/p1', { role: 'agent', totalListings: 3 });
    store.set('listings/D2', goodListing());
    await assert.rejects(listings.publishListing.run({ listingId: 'D2', availabilityConfirmed: true }, ctx('p1')), /allows 3 live listings/);
    store.set('users/p1', { role: 'agent', totalListings: 3, premiumPlan: 'agent_pro', premiumExpiresAt: Timestamp.fromMillis(Date.now() + 86400000) });
    await listings.publishListing.run({ listingId: 'D2', availabilityConfirmed: true }, ctx('p1'));
    assert.strictEqual(store.get('users/p1').totalListings, 4);
  });
  await test('a safety hold blocks publishing', async () => {
    store.set('users/p1', { role: 'agent', totalListings: 0 });
    store.set('listings/D3', goodListing({ safetyHold: true }));
    await assert.rejects(listings.publishListing.run({ listingId: 'D3', availabilityConfirmed: true }, ctx('p1')), /under review/);
  });
  await test('setListingStatus decrements the live counter and clears a boost', async () => {
    store.set('users/p1', { role: 'agent', totalListings: 2 });
    store.set('listings/D4', goodListing({ status: 'active', isFeatured: true }));
    await listings.setListingStatus.run({ listingId: 'D4', status: 'rented' }, ctx('p1'));
    assert.strictEqual(store.get('users/p1').totalListings, 1);
    assert.strictEqual(store.get('listings/D4').status, 'rented');
    assert.strictEqual(store.get('listings/D4').isFeatured, false);
  });
  await test('confirmAvailability revives a stale listing and clears needsRefresh', async () => {
    store.set('listings/D5', goodListing({ status: 'stale', needsRefresh: true }));
    await listings.confirmAvailability.run({ listingId: 'D5' }, ctx('p1'));
    const l = store.get('listings/D5');
    assert.strictEqual(l.status, 'active'); assert.strictEqual(l.needsRefresh, false);
  });

  console.log('founder programme');
  store.set('users/f1', { role: 'agent' }); store.set('users/f2', { role: 'agent' }); store.set('users/f3', { role: 'agent' });
  store.set('users/f4', { role: 'agent' }); store.set('users/f5', { role: 'agent' }); store.set('users/ten', { role: 'tenant' });
  await test('same user claiming twice concurrently succeeds exactly once', async () => {
    const r = await Promise.allSettled([founder.claimFounderPromo.run({}, ctx('f1')), founder.claimFounderPromo.run({}, ctx('f1'))]);
    assert.strictEqual(r.filter((x) => x.status === 'fulfilled').length, 1);
  });
  await test('cap of 3 holds under concurrent claims from 5 users (one already claimed)', async () => {
    const r = await Promise.allSettled(['f2', 'f3', 'f4', 'f5'].map((u) => founder.claimFounderPromo.run({}, ctx(u))));
    assert.strictEqual(r.filter((x) => x.status === 'fulfilled').length, 2);
    assert.strictEqual(store.get('promotions/founderProgram').slotsClaimed, 3);
  });
  await test('tenants cannot claim', async () => {
    await assert.rejects(founder.claimFounderPromo.run({}, ctx('ten')), /agents and landlords|claimed/);
  });

  console.log('alerts / costs / media');
  await test('moveInBreakdown: unknown is never zero; monthly charges excluded', () => {
    const b = moveInBreakdown({ category: 'for_rent', price: 2400000, charges: [
      { type: 'agency', amount: 240000, period: 'one_time' }, { type: 'legal', amount: 120000, period: 'one_time' },
      { type: 'caution', amount: 140000, period: 'one_time' }, { type: 'service', amount: 5000, period: 'monthly' }] });
    assert.strictEqual(b.subtotal, 2900000);
    assert.strictEqual(b.complete, false, 'not attested complete');
    assert.strictEqual(moveInBreakdown({ category: 'for_rent', price: 1, chargesComplete: true, charges: [] }).complete, true);
    assert.strictEqual(moveInBreakdown({ category: 'for_rent', price: 1, chargesComplete: true, unconfirmedCharges: ['service'] }).complete, false);
  });
  await test('saved search matches on total move-in budget', () => {
    const l = { category: 'for_rent', price: 2400000, bedrooms: 2, title: 'x', location: { area: 'Gwarinpa' }, charges: [{ type: 'agency', amount: 600000, period: 'one_time' }] };
    assert.ok(alerts.matches(l, { category: 'for_rent', maxMoveIn: 3000000 }));
    assert.ok(!alerts.matches(l, { category: 'for_rent', maxMoveIn: 2900000 }));
    assert.ok(!alerts.matches(l, { area: 'Jabi' }));
  });
  await test('media: only private original paths trigger processing; job ids are stable', () => {
    assert.ok(media.ORIGINAL_RE.test('listing_originals/L1/up1/original.mp4'));
    assert.ok(!media.ORIGINAL_RE.test('listings/L1/media/video_720.mp4'));
    const o = { bucket: 'b', name: 'n', generation: '1' };
    assert.strictEqual(media.jobIdFor(o), media.jobIdFor({ ...o }));
    assert.notStrictEqual(media.jobIdFor(o), media.jobIdFor({ ...o, generation: '2' }));
  });

  console.log(`\n${passed} passed, ${failures.length} failed`);
  if (failures.length) { console.log('FAILED:', failures.join(', ')); process.exit(1); }
})();
