/**
 * Saved-search alerts — opted-in, relevant, capped. A match creates an
 * in-app notification (push/WhatsApp/email delivery needs separate consent
 * and a real fulfilment path before it is switched on).
 */
const functions = require('firebase-functions/v1');
const { db, FieldValue, Timestamp } = require('./admin');
const { moveInBreakdown } = require('./cost');

function matches(listing, s) {
  if (s.category && listing.category !== s.category) return false;
  if (s.propertyType && listing.propertyType !== s.propertyType) return false;
  if (s.area && (!listing.location || listing.location.area !== s.area)) return false;
  if (s.minBedrooms != null && (listing.bedrooms || 0) < s.minBedrooms) return false;
  if (s.minPrice != null && (listing.price || 0) < s.minPrice) return false;
  if (s.maxPrice != null && (listing.price || 0) > s.maxPrice) return false;
  if (s.maxMoveIn != null && moveInBreakdown(listing).subtotal > s.maxMoveIn) return false;
  if (s.query) {
    const q = String(s.query).toLowerCase();
    const hay = `${listing.title || ''} ${listing.description || ''} ${(listing.location || {}).area || ''}`.toLowerCase();
    if (!hay.includes(q)) return false;
  }
  return true;
}

exports.checkSavedSearches = functions.pubsub.schedule('every 15 minutes').onRun(async () => {
  const cursorRef = db.collection('system').doc('savedSearchCursor');
  const cursor = await cursorRef.get();
  const last = cursor.exists && cursor.data().lastCheckedAt ? cursor.data().lastCheckedAt : Timestamp.fromMillis(Date.now() - 20 * 60 * 1000);
  const now = Timestamp.now();

  // Alerts fire when a home goes live, not when a draft is created.
  const fresh = await db.collection('listings').where('status', '==', 'active').where('publishedAt', '>', last).get();
  if (fresh.empty) { await cursorRef.set({ lastCheckedAt: now }, { merge: true }); return null; }
  const searches = await db.collection('saved_searches').where('alertsEnabled', '==', true).get();
  const listings = fresh.docs.map((d) => ({ id: d.id, ...d.data() }));

  // Respect the Settings toggle: preferences.searchAlerts === false means no alerts.
  const optedOut = new Map();
  async function alertsOff(uid) {
    if (!optedOut.has(uid)) {
      const u = await db.collection('users').doc(uid).get();
      const prefs = u.exists && u.data().preferences;
      optedOut.set(uid, !!(prefs && prefs.searchAlerts === false));
    }
    return optedOut.get(uid);
  }

  let batch = db.batch(); let ops = 0; let count = 0;
  for (const sd of searches.docs) {
    const s = sd.data();
    if (await alertsOff(s.userId)) continue;
    const found = listings.filter((l) => l.agentId !== s.userId && matches(l, s)).slice(0, 3);
    if (!found.length) continue;
    for (const l of found) {
      batch.set(db.collection('notifications').doc(), {
        userId: s.userId, type: 'saved_search_match',
        title: 'A home matches your search',
        body: `${l.title || 'A new home'} · ${(l.location && l.location.area) || ''}`.trim(),
        route: `/listing/${l.id}`, isRead: false, createdAt: FieldValue.serverTimestamp(),
      });
      ops++; count++;
    }
    batch.update(sd.ref, { lastMatchedAt: FieldValue.serverTimestamp() }); ops++;
    if (ops >= 400) { await batch.commit(); batch = db.batch(); ops = 0; }
  }
  batch.set(cursorRef, { lastCheckedAt: now }, { merge: true });
  await batch.commit();
  console.log(`checkSavedSearches: ${count} notifications from ${listings.length} new homes.`);
  return null;
});

module.exports.matches = matches;
