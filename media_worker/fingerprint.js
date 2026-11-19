/**
 * Video fingerprint and footage-age checks.
 *
 * A fingerprint is the 64-bit average hash of 12 evenly spaced frames, as hex.
 * Two videos "match" when enough frames of one have a near-identical frame in
 * the other. This catches the same footage re-posted (even re-encoded). It does
 * not prove where a video was filmed, and phone metadata can be stripped, so a
 * match or an old date is a reason for a person to look, never an automatic
 * rejection.
 */
const { hamming } = require('./analyze');

const SAMPLES = 12;
const NEAR = 8;          // max differing bits (of 64) for "same frame"
const MATCH_FRAMES = 4;  // frames that must match for "same footage"
const OLD_DAYS = 45;

function makeFingerprint(frames, n = SAMPLES) {
  if (!frames || frames.length === 0) return [];
  const out = [];
  const step = Math.max(1, Math.floor(frames.length / n));
  for (let i = 0; i < frames.length && out.length < n; i += step) out.push(frames[i].hash.toString(16));
  return out;
}

function matchScore(a, b) {
  if (!a || !b || !a.length || !b.length) return 0;
  const bb = b.map((h) => BigInt('0x' + h));
  let n = 0;
  for (const h of a) {
    const x = BigInt('0x' + h);
    if (bb.some((y) => hamming(x, y) <= NEAR)) n++;
  }
  return n;
}

function isSameFootage(a, b) { return matchScore(a, b) >= MATCH_FRAMES; }

/** Returns null, or { daysOld } when the phone's recording date is much older than the upload. */
function oldFootage(creationTime, nowMs = Date.now()) {
  if (!creationTime) return null;
  const t = Date.parse(creationTime);
  if (!Number.isFinite(t) || t > nowMs + 24 * 3600 * 1000) return null;
  const days = Math.floor((nowMs - t) / (24 * 3600 * 1000));
  return days > OLD_DAYS ? { daysOld: days } : null;
}

/**
 * others: [{ jobId, listingId, ownerUid, hashes }] from earlier videos.
 * Returns flags: [{ type: 'reused_footage' | 'same_owner_reuse', otherListingId, otherJobId, score }]
 */
function findMatches(hashes, others, { jobId, listingId, ownerUid }) {
  const flags = [];
  for (const o of others) {
    if (o.jobId === jobId || o.listingId === listingId) continue;
    const score = matchScore(hashes, o.hashes);
    if (score >= MATCH_FRAMES) {
      flags.push({ type: o.ownerUid === ownerUid ? 'same_owner_reuse' : 'reused_footage', otherListingId: o.listingId, otherJobId: o.jobId, score });
    }
  }
  return flags.sort((x, y) => y.score - x.score).slice(0, 3);
}

module.exports = { makeFingerprint, matchScore, isSameFootage, oldFootage, findMatches, SAMPLES, NEAR, MATCH_FRAMES, OLD_DAYS };
