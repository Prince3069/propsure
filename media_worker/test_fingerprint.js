const assert = require('assert');
const FP = require('./fingerprint');
function frames(seed, n = 24) {
  let x = BigInt(seed);
  return Array.from({ length: n }, (_, i) => { x = (x * 6364136223846793005n + 1442695040888963407n) & ((1n << 64n) - 1n); return { hash: x, tSec: i / 2 }; });
}
const a = FP.makeFingerprint(frames(1));
assert.strictEqual(a.length, 12);
// same footage, a few bits changed per frame (re-encode)
const reenc = a.map((h) => (BigInt('0x' + h) ^ 0b101n).toString(16));
assert.ok(FP.isSameFootage(a, reenc));
const other = FP.makeFingerprint(frames(999));
assert.ok(!FP.isSameFootage(a, other));
const m = FP.findMatches(a, [
  { jobId: 'j2', listingId: 'L2', ownerUid: 'u2', hashes: reenc },
  { jobId: 'j3', listingId: 'L3', ownerUid: 'u1', hashes: a },
  { jobId: 'j4', listingId: 'L4', ownerUid: 'u9', hashes: other },
  { jobId: 'self', listingId: 'L1', ownerUid: 'u1', hashes: a },
], { jobId: 'j1', listingId: 'L1', ownerUid: 'u1' });
assert.deepStrictEqual(m.map((x) => x.type).sort(), ['reused_footage', 'same_owner_reuse']);
const now = Date.parse('2026-11-19T12:00:00Z');
assert.strictEqual(FP.oldFootage('2026-11-10T00:00:00Z', now), null);
assert.strictEqual(FP.oldFootage('2026-01-01T00:00:00Z', now).daysOld > 300, true);
assert.strictEqual(FP.oldFootage(null, now), null);
assert.strictEqual(FP.oldFootage('2030-01-01T00:00:00Z', now), null);
console.log('fingerprint tests passed');
