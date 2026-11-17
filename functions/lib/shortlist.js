/**
 * Shared shortlists. Membership changes only happen here (rules forbid a
 * client from editing memberIds), so "only invited people can see your notes"
 * is enforced by the server.
 */
const functions = require('firebase-functions/v1');
const crypto = require('crypto');
const { db, FieldValue, Timestamp, DAY_MS } = require('./admin');

const MAX_MEMBERS = 5;

exports.createShortlistInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Please sign in first.');
  const { shortlistId } = data || {};
  const snap = await db.collection('shortlists').doc(String(shortlistId || '_')).get();
  if (!snap.exists || snap.data().ownerId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the owner can invite people.');
  }
  const code = crypto.randomBytes(9).toString('base64url');
  await db.collection('shortlist_invites').doc(code).set({
    shortlistId: snap.id, ownerId: context.auth.uid, createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 7 * DAY_MS),
  });
  return { code, url: `https://propsure.africa/s/${code}` };
});

exports.joinShortlist = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in to join this shortlist.');
  const uid = context.auth.uid;
  const code = String((data && data.code) || '');
  const inviteRef = db.collection('shortlist_invites').doc(code || '_');
  return db.runTransaction(async (t) => {
    const inv = await t.get(inviteRef);
    if (!inv.exists || inv.data().expiresAt.toMillis() < Date.now()) {
      throw new functions.https.HttpsError('not-found', 'This invitation has expired. Ask for a new one.');
    }
    const listRef = db.collection('shortlists').doc(inv.data().shortlistId);
    const [list, user] = await Promise.all([t.get(listRef), t.get(db.collection('users').doc(uid))]);
    if (!list.exists) throw new functions.https.HttpsError('not-found', 'This shortlist no longer exists.');
    const s = list.data();
    if (s.memberIds.includes(uid)) return { shortlistId: list.id, alreadyMember: true };
    if (s.memberIds.length >= MAX_MEMBERS) throw new functions.https.HttpsError('resource-exhausted', 'This shortlist is full.');
    const name = (user.exists && user.data().name) || 'Member';
    t.update(listRef, {
      memberIds: [...s.memberIds, uid],
      [`memberNames.${uid}`]: name,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { shortlistId: list.id, alreadyMember: false };
  });
});
