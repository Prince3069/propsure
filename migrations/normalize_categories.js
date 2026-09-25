/**
 * One-time migration: normalize every listing's `category` field to the
 * canonical machine value (for_rent / for_sale / short_stay / commercial).
 *
 * Why this exists: before this fix, screens wrote the raw UI label
 * ("For Rent", "Short Stay", ...) straight into Firestore. The app-side
 * fix (ListingCategory.fromAny normalizing on every read) means existing
 * documents keep WORKING without running this — but they'll still contain
 * the wrong literal value until you run it, which matters for anything
 * that reads Firestore directly (exports, BigQuery, admin tools, Cloud
 * Functions doing a raw `where('category', '==', 'for_rent')`).
 *
 * Usage:
 *   1. Download a service account key for propsure-d8f44 from
 *      Firebase Console > Project Settings > Service Accounts.
 *   2. GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node normalize_categories.js
 *   3. Re-run is safe — already-canonical documents are skipped.
 */

const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

function normalize(raw) {
  if (!raw) return 'for_rent';
  const v = String(raw).trim().toLowerCase().replace(/[- ]/g, '_');
  switch (v) {
    case 'for_rent':
    case 'rent':
      return 'for_rent';
    case 'for_sale':
    case 'sale':
      return 'for_sale';
    case 'short_stay':
    case 'shortstay':
      return 'short_stay';
    case 'commercial':
      return 'commercial';
    default:
      return 'for_rent';
  }
}

async function run() {
  const snap = await db.collection('listings').get();
  console.log(`Scanning ${snap.size} listings...`);

  let batch = db.batch();
  let opsInBatch = 0;
  let changed = 0;

  for (const doc of snap.docs) {
    const current = doc.data().category;
    const canonical = normalize(current);
    if (current !== canonical) {
      batch.update(doc.ref, { category: canonical });
      changed++;
      opsInBatch++;
      if (opsInBatch === 400) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    }
  }
  if (opsInBatch > 0) await batch.commit();

  console.log(`Done. ${changed} of ${snap.size} documents needed normalization.`);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
