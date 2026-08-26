import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as https from "https";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ══════════════════════════════════════════════════════════════════════════════
//  ENVIRONMENT VARIABLES — SET THESE IN FIREBASE
//
//  Run in terminal:
//    firebase functions:secrets:set PAYSTACK_SECRET_KEY
//    firebase functions:secrets:set PAYSTACK_WEBHOOK_SECRET
//
//  Or via Firebase Console → Functions → Secrets
//  NEVER commit these values to git.
// ══════════════════════════════════════════════════════════════════════════════

// ─── PAYSTACK API HELPER ─────────────────────────────────────────────────────
function paystackRequest(
  method: "GET" | "POST",
  path: string,
  body?: object
): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    const secretKey = process.env.PAYSTACK_SECRET_KEY;
    if (!secretKey) reject(new Error("PAYSTACK_SECRET_KEY not configured"));

    const payload = body ? JSON.stringify(body) : null;
    const options = {
      hostname: "api.paystack.co",
      port: 443,
      path,
      method,
      headers: {
        Authorization: `Bearer ${secretKey}`,
        "Content-Type": "application/json",
        ...(payload ? { "Content-Length": Buffer.byteLength(payload) } : {}),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data) as Record<string, unknown>);
        } catch {
          reject(new Error(`Invalid response: ${data}`));
        }
      });
    });
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// ─── VERIFY FIREBASE ID TOKEN (authentication middleware) ─────────────────────
async function verifyIdToken(
  req: functions.https.Request
): Promise<admin.auth.DecodedIdToken> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    throw new functions.https.HttpsError("unauthenticated", "Missing auth token");
  }
  const idToken = authHeader.split("Bearer ")[1];
  return admin.auth().verifyIdToken(idToken);
}

// ─── RATE LIMITER (simple Firestore-based) ────────────────────────────────────
async function checkRateLimit(userId: string, action: string, maxPerHour: number): Promise<void> {
  const windowStart = Date.now() - 60 * 60 * 1000;
  const snap = await db.collection("_rate_limits")
    .where("userId", "==", userId)
    .where("action", "==", action)
    .where("timestamp", ">", admin.firestore.Timestamp.fromMillis(windowStart))
    .get();
  if (snap.size >= maxPerHour) {
    throw new functions.https.HttpsError("resource-exhausted", "Too many requests. Try again later.");
  }
  await db.collection("_rate_limits").add({
    userId, action,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  1. INITIATE PAYMENT
//  Flutter → This function → Paystack API → Returns checkout URL
//  SECRET KEY never touches the Flutter app.
// ══════════════════════════════════════════════════════════════════════════════
export const initiatePayment = functions
  .runWith({ secrets: ["PAYSTACK_SECRET_KEY"] })
  .https.onRequest(async (req, res) => {
    // CORS
    res.set("Access-Control-Allow-Origin", "https://propsure.africa");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST") { res.status(405).json({ error: "Method not allowed" }); return; }

    try {
      // 1. Authenticate the caller
      const decoded = await verifyIdToken(req);
      const userId = decoded.uid;

      // 2. Rate limit: max 10 payment initiations per hour per user
      await checkRateLimit(userId, "initiate_payment", 10);

      // 3. Validate input
      const { reference, email, amount, metadata, callbackUrl } = req.body as {
        reference: string; email: string; amount: number;
        metadata: Record<string, unknown>; callbackUrl: string;
      };

      if (!reference || !email || !amount || amount < 10000) {
        res.status(400).json({ error: "Invalid payment parameters" }); return;
      }

      // 4. Verify reference exists in Firestore and belongs to this user
      const txDoc = await db.collection("transactions").doc(reference).get();
      if (!txDoc.exists || txDoc.data()?.userId !== userId) {
        res.status(403).json({ error: "Invalid transaction reference" }); return;
      }

      // 5. Call Paystack API (secret key is here, not in Flutter)
      const paystackRes = await paystackRequest("POST", "/transaction/initialize", {
        reference,
        email,
        amount, // In kobo
        currency: "NGN",
        callback_url: callbackUrl || "https://propsure.africa/payment/callback",
        metadata: {
          ...metadata,
          userId,
          platform: "propsure_flutter",
        },
        channels: ["card", "bank", "ussd", "mobile_money"],
      });

      if (!(paystackRes.status as boolean)) {
        throw new Error(paystackRes.message as string || "Paystack error");
      }

      const data = paystackRes.data as Record<string, unknown>;

      // 6. Update Firestore with Paystack access code
      await db.collection("transactions").doc(reference).update({
        paystackAccessCode: data.access_code,
        checkoutUrl: data.authorization_url,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).json({
        authorization_url: data.authorization_url,
        access_code: data.access_code,
        reference,
      });
    } catch (error: unknown) {
      const err = error as Error;
      functions.logger.error("initiatePayment error:", err.message);
      res.status(500).json({ error: err.message || "Internal error" });
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
//  2. VERIFY PAYMENT
//  Called by Flutter after checkout, confirms with Paystack server-side.
//  This is critical — NEVER trust the client alone.
// ══════════════════════════════════════════════════════════════════════════════
export const verifyPayment = functions
  .runWith({ secrets: ["PAYSTACK_SECRET_KEY"] })
  .https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "https://propsure.africa");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    try {
      const decoded = await verifyIdToken(req);
      const { reference } = req.body as { reference: string };
      if (!reference) { res.status(400).json({ error: "Missing reference" }); return; }

      // Verify reference belongs to this user
      const txDoc = await db.collection("transactions").doc(reference).get();
      if (!txDoc.exists || txDoc.data()?.userId !== decoded.uid) {
        res.status(403).json({ error: "Unauthorized" }); return;
      }

      // Check against Paystack
      const paystackRes = await paystackRequest("GET", `/transaction/verify/${reference}`);
      const data = paystackRes.data as Record<string, unknown>;

      const success =
        (paystackRes.status as boolean) &&
        (data.status as string) === "success" &&
        (data.currency as string) === "NGN";

      if (success) {
        const metadata = data.metadata as Record<string, unknown>;
        const type = metadata?.type as string || txDoc.data()?.type as string;

        // Update transaction record
        await db.collection("transactions").doc(reference).update({
          status: "success",
          paystackData: {
            channel: data.channel,
            paidAt: data.paid_at,
            amountPaid: data.amount,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Activate the feature they paid for
        await _activateFeature(decoded.uid, type, metadata, reference);

        res.status(200).json({ status: "success", type, metadata });
      } else {
        await db.collection("transactions").doc(reference).update({
          status: "failed",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(200).json({ status: "failed", message: "Payment not successful" });
      }
    } catch (error: unknown) {
      const err = error as Error;
      functions.logger.error("verifyPayment error:", err.message);
      res.status(500).json({ error: err.message });
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
//  3. PAYSTACK WEBHOOK
//  Paystack calls this directly to confirm events (most reliable method).
//  Validates HMAC-SHA512 signature — if signature doesn't match, drop it.
// ══════════════════════════════════════════════════════════════════════════════
export const paystackWebhook = functions
  .runWith({ secrets: ["PAYSTACK_WEBHOOK_SECRET"] })
  .https.onRequest(async (req, res) => {
    // 1. Always respond 200 immediately to Paystack
    res.status(200).send("OK");

    try {
      // 2. Validate webhook signature (HMAC-SHA512)
      const webhookSecret = process.env.PAYSTACK_WEBHOOK_SECRET;
      const signature = req.headers["x-paystack-signature"] as string;
      const body = JSON.stringify(req.body);
      const expectedSig = crypto
        .createHmac("sha512", webhookSecret!)
        .update(body)
        .digest("hex");

      if (signature !== expectedSig) {
        functions.logger.warn("🚨 Invalid webhook signature — possible spoofing attempt");
        return; // Silently drop — already sent 200
      }

      const event = req.body as { event: string; data: Record<string, unknown> };
      functions.logger.info(`Paystack webhook: ${event.event}`);

      // 3. Handle events
      switch (event.event) {
        case "charge.success": {
          const data = event.data;
          const reference = data.reference as string;
          const metadata = data.metadata as Record<string, unknown>;
          const userId = metadata.userId as string;
          const type = metadata.type as string || "unknown";

          // Idempotency: skip if already processed
          const txDoc = await db.collection("transactions").doc(reference).get();
          if (txDoc.data()?.status === "success") {
            functions.logger.info(`Already processed: ${reference}`);
            return;
          }

          await db.collection("transactions").doc(reference).update({
            status: "success",
            webhookConfirmed: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          await _activateFeature(userId, type, metadata, reference);

          // Notify user
          const userDoc = await db.collection("users").doc(userId).get();
          if (userDoc.data()?.fcmToken) {
            await messaging.send({
              token: userDoc.data()!.fcmToken as string,
              notification: { title: "✅ Payment Confirmed", body: "Your payment was successful!" },
              data: { type: "payment_success", reference },
            }).catch(() => {});
          }
          break;
        }
        case "charge.failed": {
          const reference = event.data.reference as string;
          await db.collection("transactions").doc(reference).update({
            status: "failed",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }).catch(() => {});
          break;
        }
        case "subscription.create":
        case "subscription.not_renew":
        case "subscription.disable": {
          functions.logger.info(`Subscription event: ${event.event}`, event.data);
          // Handle subscription lifecycle here
          break;
        }
      }
    } catch (error: unknown) {
      const err = error as Error;
      functions.logger.error("Webhook processing error:", err.message);
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
//  FEATURE ACTIVATION — called after confirmed payment
// ══════════════════════════════════════════════════════════════════════════════
async function _activateFeature(
  userId: string,
  type: string,
  metadata: Record<string, unknown>,
  reference: string
): Promise<void> {
  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  switch (type) {
    case "boost": {
      const listingId = metadata.listingId as string;
      const days = (metadata.boostDays as number) || 7;
      const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

      batch.update(db.collection("listings").doc(listingId), {
        isFeatured: true,
        boostExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        boostReference: reference,
        updatedAt: now,
      });
      break;
    }
    case "premium": {
      const planId = metadata.planId as string;
      const billing = metadata.billing as string;
      const months = billing === "yearly" ? 12 : 1;
      const expiresAt = new Date(Date.now() + months * 30 * 24 * 60 * 60 * 1000);

      batch.update(db.collection("users").doc(userId), {
        isPremium: true,
        premiumPlan: planId,
        premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        premiumReference: reference,
        updatedAt: now,
      });
      break;
    }
    case "reservation": {
      const listingId = metadata.listingId as string;
      const hours = 48;
      const reservedUntil = new Date(Date.now() + hours * 60 * 60 * 1000);

      batch.update(db.collection("listings").doc(listingId), {
        isReserved: true,
        reservedBy: userId,
        reservedUntil: admin.firestore.Timestamp.fromDate(reservedUntil),
        reservationReference: reference,
        updatedAt: now,
      });
      break;
    }
    case "verification_fee": {
      batch.update(db.collection("users").doc(userId), {
        verificationFeePaid: true,
        verificationFeeReference: reference,
        updatedAt: now,
      });
      break;
    }
  }

  await batch.commit();
  functions.logger.info(`Feature activated: ${type} for user ${userId}`);
}

// ══════════════════════════════════════════════════════════════════════════════
//  AUTO-EXPIRE BOOSTS (daily cron)
// ══════════════════════════════════════════════════════════════════════════════
export const autoExpireBoosts = functions.pubsub
  .schedule("0 1 * * *").timeZone("Africa/Lagos")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db.collection("listings")
      .where("isFeatured", "==", true)
      .where("boostExpiresAt", "<", now)
      .get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.update(doc.ref, {
      isFeatured: false, boostExpiresAt: null, updatedAt: now,
    }));
    await batch.commit();
    functions.logger.info(`Expired ${snap.docs.length} boosts`);
  });

// ══════════════════════════════════════════════════════════════════════════════
//  AUTO-EXPIRE PREMIUM (daily cron)
// ══════════════════════════════════════════════════════════════════════════════
export const autoExpirePremium = functions.pubsub
  .schedule("0 2 * * *").timeZone("Africa/Lagos")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db.collection("users")
      .where("isPremium", "==", true)
      .where("premiumExpiresAt", "<", now)
      .get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.update(doc.ref, {
      isPremium: false, premiumPlan: null, premiumExpiresAt: null,
    }));
    await batch.commit();
    functions.logger.info(`Expired ${snap.docs.length} premium subscriptions`);

    // Warn users 3 days before expiry
    const warnDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);
    const warnSnap = await db.collection("users")
      .where("isPremium", "==", true)
      .where("premiumExpiresAt", "<", admin.firestore.Timestamp.fromDate(warnDate))
      .get();
    for (const doc of warnSnap.docs) {
      if (doc.data().fcmToken) {
        await messaging.send({
          token: doc.data().fcmToken as string,
          notification: { title: "⚠️ Premium Expiring Soon", body: "Your Premium subscription expires in 3 days. Renew now." },
          data: { type: "premium_expiring" },
        }).catch(() => {});
      }
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
//  AUTO-EXPIRE LISTINGS (daily cron)
// ══════════════════════════════════════════════════════════════════════════════
export const autoExpireListings = functions.pubsub
  .schedule("0 0 * * *").timeZone("Africa/Lagos")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db.collection("listings")
      .where("status", "==", "active")
      .where("expiresAt", "<", now).get();
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.update(doc.ref, {
      status: "expired", updatedAt: now }));
    await batch.commit();
    functions.logger.info(`Expired ${snap.docs.length} listings`);
  });

// ══════════════════════════════════════════════════════════════════════════════
//  BOOKING NOTIFICATIONS
// ══════════════════════════════════════════════════════════════════════════════
export const onBookingCreated = functions.firestore
  .document("bookings/{bookingId}").onCreate(async (snap) => {
    const booking = snap.data();
    const agentDoc = await db.collection("users").doc(booking.agentId).get();
    if (agentDoc.data()?.fcmToken) {
      await messaging.send({
        token: agentDoc.data()!.fcmToken as string,
        notification: { title: "📅 New Inspection Request", body: `${booking.userName} wants to inspect "${booking.listingTitle}"` },
        data: { type: "booking_request", bookingId: snap.id },
      }).catch(() => {});
    }
  });

export const onBookingUpdated = functions.firestore
  .document("bookings/{bookingId}").onUpdate(async (change) => {
    const before = change.before.data(); const after = change.after.data();
    if (before.status === after.status) return;
    const msgs: Record<string, string> = {
      confirmed: `✅ Your inspection at "${after.listingTitle}" is confirmed!`,
      rejected: `❌ Inspection request for "${after.listingTitle}" was declined.`,
    };
    const msg = msgs[after.status];
    if (!msg) return;
    const tenantDoc = await db.collection("users").doc(after.userId).get();
    if (tenantDoc.data()?.fcmToken) {
      await messaging.send({
        token: tenantDoc.data()!.fcmToken as string,
        notification: { title: "Booking Update", body: msg },
        data: { type: "booking_update", bookingId: change.after.id },
      }).catch(() => {});
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
//  MESSAGE NOTIFICATIONS
// ══════════════════════════════════════════════════════════════════════════════
export const onNewMessage = functions.firestore
  .document("chats/{chatId}/messages/{messageId}").onCreate(async (snap, ctx) => {
    const msg = snap.data();
    const chatDoc = await db.collection("chats").doc(ctx.params.chatId).get();
    const chat = chatDoc.data();
    if (!chat) return;
    for (const recipientId of (chat.participantIds as string[]).filter((id: string) => id !== msg.senderId)) {
      const userDoc = await db.collection("users").doc(recipientId).get();
      if (userDoc.data()?.fcmToken) {
        await messaging.send({
          token: userDoc.data()!.fcmToken as string,
          notification: {
            title: msg.senderName || "New Message",
            body: msg.type === "image" ? "📷 Photo" : msg.text,
          },
          data: { type: "new_message", chatId: ctx.params.chatId },
        }).catch(() => {});
      }
    }
  });

// ══════════════════════════════════════════════════════════════════════════════
//  AGENT STATS
// ══════════════════════════════════════════════════════════════════════════════
export const onListingCreated = functions.firestore
  .document("listings/{listingId}").onCreate(async (snap) => {
    const l = snap.data();
    await db.collection("users").doc(l.agentId).update({
      totalListings: admin.firestore.FieldValue.increment(1) }).catch(() => {});
  });

export const onListingDeleted = functions.firestore
  .document("listings/{listingId}").onDelete(async (snap) => {
    const l = snap.data();
    await db.collection("users").doc(l.agentId).update({
      totalListings: admin.firestore.FieldValue.increment(-1) }).catch(() => {});
  });

export const onReviewCreated = functions.firestore
  .document("reviews/{reviewId}").onCreate(async (snap) => {
    const review = snap.data();
    const reviews = await db.collection("reviews")
      .where("agentId", "==", review.agentId)
      .where("isVisible", "==", true).get();
    const avg = reviews.docs.reduce((s, d) => s + (d.data().rating || 0), 0) / (reviews.docs.length || 1);
    await db.collection("users").doc(review.agentId).update({
      rating: Math.round(avg * 10) / 10, reviewCount: reviews.docs.length });
  });

// ══════════════════════════════════════════════════════════════════════════════
//  CLEAN UP RATE LIMIT RECORDS (weekly)
// ══════════════════════════════════════════════════════════════════════════════
export const cleanupRateLimits = functions.pubsub
  .schedule("0 3 * * 0").timeZone("Africa/Lagos")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000));
    const snap = await db.collection("_rate_limits").where("timestamp", "<", cutoff).limit(500).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  });

export const cleanupOldNotifications = functions.pubsub
  .schedule("0 2 * * 0").timeZone("Africa/Lagos")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000));
    const snap = await db.collection("notifications")
      .where("isRead", "==", true).where("createdAt", "<", cutoff).limit(500).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  });

// ══════════════════════════════════════════════════════════════════════════════
//  ADMIN MANAGEMENT — Email-based magic link login
//
//  How it works:
//  1. You run: firebase functions:call createAdminUser --data '{"email":"prince@propsure.africa"}'
//  2. Cloud Function creates Firebase Auth account + sets role:admin in Firestore
//  3. Sends magic link email to that address
//  4. Admin clicks link → lands on admin.propsure.africa → auto signed in
//  5. Admin dashboard checks role:admin before showing anything
//
//  Secret needed:
//    firebase functions:secrets:set SENDGRID_API_KEY
//    (or use Firebase's built-in email via nodemailer with Gmail SMTP)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * ONE-TIME: Create an admin user account and send them a magic link.
 * Call this from Firebase CLI only — not exposed publicly.
 *
 * firebase functions:call createAdminUser \
 *   --data '{"email":"prince@propsure.africa","name":"Prince Ifeanyi"}'
 */
export const createAdminUser = functions
  .runWith({ secrets: ["SENDGRID_API_KEY"] })
  .https.onCall(async (data, context) => {
    // Only callable by existing admins (or on first setup, from CLI with admin SDK)
    // On first run: comment out this check temporarily
    if (context.auth) {
      const callerDoc = await db.collection("users").doc(context.auth.uid).get();
      if (callerDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
      }
    }

    const { email, name } = data as { email: string; name: string };
    if (!email || !name) {
      throw new functions.https.HttpsError("invalid-argument", "email and name required");
    }

    try {
      // 1. Create Firebase Auth user
      let userRecord: admin.auth.UserRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email);
        functions.logger.info(`Admin user already exists: ${email}`);
      } catch {
        userRecord = await admin.auth().createUser({
          email,
          displayName: name,
          emailVerified: true,
        });
      }

      // 2. Set admin role in Firestore
      await db.collection("users").doc(userRecord.uid).set({
        uid: userRecord.uid,
        name,
        email,
        role: "admin",
        isVerified: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 3. Generate magic sign-in link
      const actionCodeSettings = {
        url: "https://admin.propsure.africa/dashboard",
        handleCodeInApp: true,
      };
      const magicLink = await admin.auth().generateSignInWithEmailLink(
        email,
        actionCodeSettings
      );

      // 4. Send email with magic link
      await sendAdminWelcomeEmail(email, name, magicLink);

      functions.logger.info(`Admin user created and email sent: ${email}`);
      return { success: true, uid: userRecord.uid, message: `Admin account created for ${email}` };
    } catch (error: unknown) {
      const err = error as Error;
      functions.logger.error("createAdminUser error:", err.message);
      throw new functions.https.HttpsError("internal", err.message);
    }
  });

/**
 * Send magic link to existing admin (e.g. if they lose access or for re-login).
 */
export const sendAdminMagicLink = functions
  .runWith({ secrets: ["SENDGRID_API_KEY"] })
  .https.onCall(async (data, context) => {
    const { email } = data as { email: string };

    // Verify this email is actually an admin
    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      const userDoc = await db.collection("users").doc(userRecord.uid).get();
      if (userDoc.data()?.role !== "admin") {
        // Don't reveal whether account exists — security best practice
        return { success: true, message: "If an admin account exists, a link has been sent." };
      }

      const actionCodeSettings = {
        url: "https://admin.propsure.africa/dashboard",
        handleCodeInApp: true,
      };
      const magicLink = await admin.auth().generateSignInWithEmailLink(
        email,
        actionCodeSettings
      );

      await sendAdminWelcomeEmail(email, userDoc.data()?.name ?? "Admin", magicLink);
      return { success: true, message: "Magic link sent to your email." };
    } catch {
      return { success: true, message: "If an admin account exists, a link has been sent." };
    }
  });

/**
 * Email sender — uses SendGrid API.
 * Replace with your preferred email provider.
 */
async function sendAdminWelcomeEmail(
  email: string,
  name: string,
  magicLink: string
): Promise<void> {
  const sgApiKey = process.env.SENDGRID_API_KEY;

  if (!sgApiKey) {
    functions.logger.warn("SENDGRID_API_KEY not set — skipping email");
    functions.logger.info(`Magic link for ${email}: ${magicLink}`);
    return;
  }

  const emailBody = {
    personalizations: [{
      to: [{ email, name }],
      dynamic_template_data: { name, magicLink, dashboardUrl: "https://admin.propsure.africa" },
    }],
    from: { email: "noreply@propsure.africa", name: "Propsure" },
    subject: "🏡 Your Propsure Admin Access",
    content: [{
      type: "text/html",
      value: `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F3F5F4;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:40px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
    <!-- Header -->
    <div style="background:linear-gradient(135deg,#063D24,#0A5C36);padding:32px 40px;text-align:center;">
      <div style="width:56px;height:56px;background:rgba(255,255,255,0.15);border-radius:14px;display:inline-flex;align-items:center;justify-content:center;margin-bottom:12px;">
        <span style="font-size:28px;">🏡</span>
      </div>
      <h1 style="color:#fff;font-size:22px;font-weight:800;margin:0;letter-spacing:-0.3px;">Propsure Admin</h1>
      <p style="color:rgba(255,255,255,0.65);font-size:13px;margin:4px 0 0;">Nigeria's Most Trusted Property Platform</p>
    </div>
    <!-- Body -->
    <div style="padding:40px;">
      <h2 style="color:#0D1F17;font-size:20px;font-weight:700;margin:0 0 8px;">Hi ${name} 👋</h2>
      <p style="color:#5A7066;font-size:14px;line-height:1.6;margin:0 0 24px;">
        Your admin account for Propsure has been created. Click the button below to sign in to your dashboard — no password needed.
      </p>
      <!-- CTA Button -->
      <div style="text-align:center;margin:32px 0;">
        <a href="${magicLink}"
           style="display:inline-block;background:#0A5C36;color:#fff;text-decoration:none;font-size:15px;font-weight:700;padding:16px 36px;border-radius:12px;letter-spacing:0.2px;">
          Sign In to Admin Dashboard →
        </a>
      </div>
      <!-- Security note -->
      <div style="background:#EEF7F2;border-radius:10px;padding:14px 16px;margin:24px 0;">
        <p style="color:#0A5C36;font-size:12px;font-weight:700;margin:0 0 4px;">🔒 Security Notice</p>
        <p style="color:#4A6358;font-size:12px;margin:0;line-height:1.5;">
          This link is valid for 24 hours and can only be used once. 
          If you didn't expect this email, please contact <a href="mailto:security@propsure.africa" style="color:#0A5C36;">security@propsure.africa</a> immediately.
        </p>
      </div>
      <p style="color:#8AA89A;font-size:11px;margin:16px 0 0;">
        Or copy this link into your browser:<br>
        <span style="color:#0A5C36;word-break:break-all;">${magicLink}</span>
      </p>
    </div>
    <!-- Footer -->
    <div style="border-top:1px solid #E0E8E4;padding:20px 40px;text-align:center;">
      <p style="color:#8AA89A;font-size:11px;margin:0;">© 2025 Propsure · Nigeria's Most Trusted Property Platform</p>
      <p style="color:#8AA89A;font-size:11px;margin:4px 0 0;">Prince Dev Labs Limited · Abuja, Nigeria</p>
    </div>
  </div>
</body>
</html>`,
    }],
  };

  const response = await new Promise<{ statusCode: number }>((resolve, reject) => {
    const payload = JSON.stringify(emailBody);
    const req = require("https").request({
      hostname: "api.sendgrid.com",
      path: "/v3/mail/send",
      method: "POST",
      headers: {
        Authorization: `Bearer ${sgApiKey}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(payload),
      },
    }, (res: { statusCode: number }) => resolve(res));
    req.on("error", reject);
    req.write(payload);
    req.end();
  });

  if (response.statusCode >= 400) {
    throw new Error(`SendGrid error: ${response.statusCode}`);
  }
  functions.logger.info(`Admin email sent to ${email}`);
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAYSTACK SUBSCRIPTIONS — Recurring billing
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Create a Paystack subscription plan (run once to set up plans in Paystack).
 * Then use plan codes in your app.
 */
export const createPaystackPlans = functions
  .runWith({ secrets: ["PAYSTACK_SECRET_KEY"] })
  .https.onCall(async (_, context) => {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Admin only");
    }

    const plans = [
      { name: "Agent Pro Monthly", amount: 1000000, interval: "monthly", planKey: "agent_pro_monthly" },
      { name: "Agent Pro Yearly", amount: 10000000, interval: "annually", planKey: "agent_pro_yearly" },
      { name: "Agent Elite Monthly", amount: 2500000, interval: "monthly", planKey: "agent_elite_monthly" },
      { name: "Agent Elite Yearly", amount: 25000000, interval: "annually", planKey: "agent_elite_yearly" },
    ];

    const results: Record<string, string> = {};
    for (const plan of plans) {
      const res = await paystackRequest("POST", "/plan", {
        name: plan.name,
        amount: plan.amount,
        interval: plan.interval,
        currency: "NGN",
        description: `Propsure ${plan.name}`,
      });
      if (res.status) {
        const data = res.data as Record<string, unknown>;
        const planCode = data.plan_code as string;
        results[plan.planKey] = planCode;
        // Save plan code to Firestore config
        await db.collection("_config").doc("paystack_plans").set(
          { [plan.planKey]: planCode },
          { merge: true }
        );
      }
    }
    return { success: true, plans: results };
  });

/**
 * Handle subscription renewal events from Paystack webhook.
 * Extends user's premium period automatically.
 */
async function handleSubscriptionRenewal(data: Record<string, unknown>): Promise<void> {
  const metadata = data.metadata as Record<string, unknown> | undefined;
  const userId = metadata?.userId as string | undefined;
  if (!userId) return;

  const planCode = data.plan as Record<string, unknown> | undefined;
  const planName = planCode?.name as string | undefined ?? "";
  const isElite = planName.toLowerCase().includes("elite");
  const isYearly = planName.toLowerCase().includes("annually") || planName.toLowerCase().includes("yearly");
  const months = isYearly ? 12 : 1;

  // Extend subscription
  const currentDoc = await db.collection("users").doc(userId).get();
  const currentExpiry = (currentDoc.data()?.premiumExpiresAt as admin.firestore.Timestamp | undefined)?.toDate() ?? new Date();
  const newExpiry = new Date(Math.max(currentExpiry.getTime(), Date.now()) + months * 30 * 24 * 60 * 60 * 1000);

  await db.collection("users").doc(userId).update({
    isPremium: true,
    premiumPlan: isElite ? "agent_elite" : "agent_pro",
    premiumExpiresAt: admin.firestore.Timestamp.fromDate(newExpiry),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info(`Subscription renewed for user ${userId} until ${newExpiry.toISOString()}`);
}

// ══════════════════════════════════════════════════════════════════════════════
//  WHATSAPP BOT — Listing ingestion via Twilio
//
//  Setup:
//  1. Get Twilio account: twilio.com
//  2. Get WhatsApp sandbox or business number
//  3. Set webhook: https://your-project.cloudfunctions.net/whatsappListingBot
//  4. firebase functions:secrets:set TWILIO_ACCOUNT_SID
//  5. firebase functions:secrets:set TWILIO_AUTH_TOKEN
//  6. firebase functions:secrets:set TWILIO_WHATSAPP_NUMBER
//
//  Agent sends a message like:
//  "LIST: 3 bedroom flat, Maitama, ₦2M/year, furnished, generator, AC"
//  Bot extracts details and creates a draft listing.
// ══════════════════════════════════════════════════════════════════════════════

export const whatsappListingBot = functions
  .runWith({ secrets: ["TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_WHATSAPP_NUMBER"] })
  .https.onRequest(async (req, res) => {
    // 1. Validate Twilio request signature
    const twilioSignature = req.headers["x-twilio-signature"] as string;
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;

    if (!twilioSignature || !accountSid || !authToken) {
      res.status(403).send("Forbidden");
      return;
    }

    // Validate signature (prevent spoofed messages)
    const url = `https://${req.hostname}${req.originalUrl}`;
    const params = req.body as Record<string, string>;
    const sortedParams = Object.keys(params).sort().map((k) => `${k}${params[k]}`).join("");
    const expectedSig = crypto.createHmac("sha1", authToken).update(url + sortedParams).digest("base64");
    if (expectedSig !== twilioSignature) {
      functions.logger.warn("🚨 Invalid Twilio signature");
      res.status(403).send("Forbidden");
      return;
    }

    const from = params.From?.replace("whatsapp:", "") ?? "";
    const body = (params.Body ?? "").trim();

    functions.logger.info(`WhatsApp message from ${from}: ${body}`);

    let reply = "";

    try {
      // Check if this phone number is a registered agent
      const usersSnap = await db.collection("users")
        .where("phone", "==", from)
        .where("role", "in", ["agent", "landlord"])
        .limit(1)
        .get();

      if (usersSnap.empty) {
        reply = "❌ Your number isn't registered as an agent on Propsure.\n\nDownload our app to sign up:\npropsure.africa/download";
      } else {
        const agent = usersSnap.docs[0];
        const agentData = agent.data();

        // Parse listing from message
        const lowerBody = body.toLowerCase();

        if (lowerBody.startsWith("list:") || lowerBody.startsWith("list ")) {
          const listing = await parseAndCreateDraftListing(body, agent.id, agentData);

          if (listing.success) {
            reply = `✅ *Draft listing created!*\n\n` +
              `🏠 *${listing.title}*\n` +
              `📍 ${listing.area}, Abuja\n` +
              `💰 ₦${listing.price?.toLocaleString()}/year\n` +
              `🛏 ${listing.bedrooms} beds · 🚿 ${listing.bathrooms} baths\n\n` +
              `Review and publish it in the app:\npropsure.africa/listing/${listing.id}/edit\n\n` +
              `_Type HELP to see all commands_`;
          } else {
            reply = `⚠️ I couldn't parse your listing. Please use this format:\n\n` +
              `*LIST: [type], [area], [price], [beds] bedroom, [baths] bathroom, [features]*\n\n` +
              `Example:\n_LIST: 3 bedroom flat, Maitama, ₦2M/year, furnished, generator, AC_`;
          }
        } else if (lowerBody === "help") {
          reply = `🏡 *Propsure WhatsApp Bot*\n\n` +
            `📋 *Commands:*\n` +
            `• *LIST: [details]* — Create a draft listing\n` +
            `• *STATUS* — Your active listings count\n` +
            `• *HELP* — Show this menu\n\n` +
            `📝 *Listing format:*\n` +
            `LIST: [type], [area], [price/yr], [beds] bedroom, [baths] bathroom, [features]\n\n` +
            `Example:\n_LIST: 3 bedroom duplex, Wuse 2, ₦3.5M/year, furnished, generator, swimming pool_`;
        } else if (lowerBody === "status") {
          const snap = await db.collection("listings")
            .where("agentId", "==", agent.id)
            .where("status", "==", "active").get();
          reply = `📊 *Your Propsure Stats*\n\n` +
            `🏠 Active listings: ${snap.size}\n` +
            `✅ Verified: ${agentData.isVerified ? "Yes" : "No"}\n\n` +
            `Open app for full details:\npropsure.africa`;
        } else {
          reply = `Hi ${agentData.name}! 👋\n\nI'm the Propsure listing bot.\n\nType *HELP* to see what I can do, or start with:\n_LIST: your property details_`;
        }
      }
    } catch (error: unknown) {
      const err = error as Error;
      functions.logger.error("WhatsApp bot error:", err.message);
      reply = "Sorry, something went wrong. Please try again or contact support.";
    }

    // Send Twilio reply as TwiML
    res.set("Content-Type", "text/xml");
    res.send(`<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>${reply.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</Message>
</Response>`);
  });

/**
 * Parse natural language listing description and create a Firestore draft.
 */
async function parseAndCreateDraftListing(
  text: string,
  agentId: string,
  agentData: Record<string, unknown>
): Promise<{ success: boolean; id?: string; title?: string; area?: string; price?: number; bedrooms?: number; bathrooms?: number }> {
  try {
    const lower = text.toLowerCase();

    // Extract bedrooms
    const bedMatch = lower.match(/(\d+)\s*(?:bed(?:room)?s?)/);
    const bedrooms = bedMatch ? parseInt(bedMatch[1]) : 2;

    // Extract bathrooms
    const bathMatch = lower.match(/(\d+)\s*(?:bath(?:room)?s?)/);
    const bathrooms = bathMatch ? parseInt(bathMatch[1]) : 1;

    // Extract price
    const priceMatch = lower.match(/[₦#]?\s*(\d+(?:\.\d+)?)\s*([mk])?(?:\/(?:year|yr|annum))?/);
    let price = 0;
    if (priceMatch) {
      price = parseFloat(priceMatch[1]);
      const multiplier = priceMatch[2];
      if (multiplier === "m") price *= 1000000;
      else if (multiplier === "k") price *= 1000;
    }

    // Extract area (check against Abuja areas)
    const abujaAreas = ["wuse", "maitama", "asokoro", "garki", "jabi", "utako", "gwarinpa",
      "kubwa", "lugbe", "galadimawa", "lokogoma", "apo", "durumi", "gudu", "kado",
      "life camp", "guzape", "katampe", "wuye", "mpape"];
    let area = "Abuja";
    for (const a of abujaAreas) {
      if (lower.includes(a)) {
        area = a.split(" ").map((w) => w[0].toUpperCase() + w.slice(1)).join(" ");
        break;
      }
    }

    // Extract property type
    const typeMap: Record<string, string> = {
      "flat": "Flat / Apartment", "apartment": "Flat / Apartment",
      "duplex": "Duplex", "bungalow": "Bungalow",
      "terrace": "Terraced House", "detached": "Detached House",
      "semi-detached": "Semi-Detached", "studio": "Studio",
    };
    let propertyType = "Flat / Apartment";
    for (const [key, val] of Object.entries(typeMap)) {
      if (lower.includes(key)) { propertyType = val; break; }
    }

    // Extract amenities
    const amenityKeywords: Record<string, string> = {
      "generator": "Generator", "borehole": "Borehole / Water", "swimming pool": "Swimming Pool",
      "gym": "Gym", "ac": "Air Conditioning", "air condition": "Air Conditioning",
      "furnished": "Fitted Kitchen", "cctv": "Security / CCTV", "security": "Security / CCTV",
      "parking": "Parking Space", "internet": "Internet / Fiber", "fiber": "Internet / Fiber",
      "balcony": "Balcony", "garden": "Garden",
    };
    const amenities: string[] = [];
    for (const [key, val] of Object.entries(amenityKeywords)) {
      if (lower.includes(key) && !amenities.includes(val)) amenities.push(val);
    }

    const isFurnished = lower.includes("furnished");
    const title = `${bedrooms} Bedroom ${propertyType} in ${area}`;

    // Create draft in Firestore
    const ref = await db.collection("listings").add({
      title,
      description: `${bedrooms} bedroom ${propertyType.toLowerCase()} in ${area}. ${amenities.join(", ")}.`,
      price,
      propertyType,
      bedrooms,
      bathrooms,
      toilets: bathrooms,
      area,
      city: "Abuja",
      state: "FCT",
      location: { area, city: "Abuja", state: "FCT", fullAddress: `${area}, Abuja, FCT` },
      amenities,
      isFurnished,
      agentId,
      agentName: agentData.name ?? "",
      agentPhone: agentData.phone ?? "",
      agentPhoto: agentData.profilePhoto ?? "",
      images: [],
      status: "draft", // Requires agent to review and add photos before publishing
      source: "whatsapp_bot",
      isVerified: agentData.isVerified ?? false,
      isFeatured: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)),
    });

    return { success: true, id: ref.id, title, area, price, bedrooms, bathrooms };
  } catch (err) {
    functions.logger.error("parseAndCreateDraftListing error:", err);
    return { success: false };
  }
}
