// One place that initialises the Admin SDK so every module can require it
// without ever calling initializeApp() twice.
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const DAY_MS = 24 * 60 * 60 * 1000;

function daysFromNow(days) {
  return Timestamp.fromMillis(Date.now() + days * DAY_MS);
}

function isPremiumUser(user) {
  if (!user || !user.premiumPlan || !user.premiumExpiresAt) return false;
  return user.premiumExpiresAt.toMillis() > Date.now();
}

module.exports = { admin, db, FieldValue, Timestamp, DAY_MS, daysFromNow, isPremiumUser };
