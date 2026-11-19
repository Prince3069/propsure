/**
 * Life around the home.
 *
 * Signed-in people report what they know about an area (power, water,
 * flooding, security, internet, roads) by choosing from fixed options. We
 * store one report per person, area and topic (a newer report replaces their
 * older one) and keep a public summary per area: how many reports, what they
 * said, and when the latest one came in. Raw reports are private.
 * Nothing is guessed: an area with no reports shows nothing.
 */
const functions = require('firebase-functions/v1');
const { db, FieldValue, Timestamp, DAY_MS } = require('./admin');

const TOPICS_AREA = {
  power: ['under6', '6to12', '12to18', '18plus'],
  water: ['borehole', 'public', 'tanker', 'unsure'],
  flooding: ['never', 'once', 'often'],
  security: ['secure', 'average', 'weak'],
  internet: ['fibre', 'mobile', 'poor'],
  roads: ['good', 'fair', 'poor'],
};

const CITY_ALIASES = {
  fct: 'abuja', 'f c t': 'abuja', 'federal capital territory': 'abuja', 'abuja municipal': 'abuja', amac: 'abuja',
  'lagos state': 'lagos', ph: 'port harcourt',
};

function slug(s) {
  return String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

/** Same rule as the app (core/utils/area.dart). */
function areaKeyOf(city, area) {
  let c = String(city || '').split(',')[0].trim().toLowerCase();
  if (CITY_ALIASES[c]) c = CITY_ALIASES[c];
  return `${slug(c)}__${slug(area)}`;
}

exports.submitAreaReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in to add a report.');
  const uid = context.auth.uid;
  const city = String((data && data.city) || '').trim().slice(0, 60);
  const area = String((data && data.area) || '').trim().slice(0, 60);
  const answers = (data && data.answers && typeof data.answers === 'object') ? data.answers : {};
  if (!city || !area) throw new functions.https.HttpsError('invalid-argument', 'Which area is this about?');
  const picked = Object.entries(answers).filter(([t, v]) => TOPICS_AREA[t] && TOPICS_AREA[t].includes(v));
  if (picked.length === 0) throw new functions.https.HttpsError('invalid-argument', 'Choose at least one answer.');
  const key = areaKeyOf(city, area);
  if (!key.split('__')[1]) throw new functions.https.HttpsError('invalid-argument', 'Which area is this about?');

  // A few reports a day per person.
  const day = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const counterRef = db.collection('system').doc(`areareport_${uid}_${day}`);
  const ok = await db.runTransaction(async (tx) => {
    const s = await tx.get(counterRef);
    const n = s.exists ? Number(s.data().count || 0) : 0;
    if (n >= 12) return false;
    tx.set(counterRef, { count: n + 1, uid, day }, { merge: true });
    return true;
  });
  if (!ok) throw new functions.https.HttpsError('resource-exhausted', 'You have added enough reports for today. Thank you.');

  // People with homes listed in this area cannot report on it.
  const own = await db.collection('listings').where('agentId', '==', uid).where('area', '==', area).limit(1).get();
  if (!own.empty) throw new functions.https.HttpsError('permission-denied', 'You have a home listed in this area, so you cannot add a report about it.');

  const cutoff = Timestamp.fromMillis(Date.now() - 365 * DAY_MS);
  const topicsOut = {};
  for (const [topic, value] of picked) {
    await db.collection('area_reports').doc(`${uid}_${key}_${topic}`).set({
      userId: uid, areaKey: key, topic, value, updatedAt: FieldValue.serverTimestamp(),
    });
    const snap = await db.collection('area_reports').where('areaKey', '==', key).where('topic', '==', topic).limit(500).get();
    const dist = {};
    let count = 0;
    let latest = 0;
    for (const d of snap.docs) {
      const r = d.data();
      const at = r.updatedAt && r.updatedAt.toMillis ? r.updatedAt.toMillis() : Date.now();
      if (at < cutoff.toMillis()) continue;
      if (!TOPICS_AREA[topic].includes(r.value)) continue;
      dist[r.value] = (dist[r.value] || 0) + 1;
      count += 1;
      if (at > latest) latest = at;
    }
    topicsOut[topic] = { count, dist, latestAt: Timestamp.fromMillis(latest || Date.now()) };
  }
  await db.collection('area_summaries').doc(key).set({
    areaKey: key, city, area, topics: topicsOut, updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return { success: true, saved: picked.length };
});

module.exports.areaKeyOf = areaKeyOf;
module.exports.TOPICS_AREA = TOPICS_AREA;
