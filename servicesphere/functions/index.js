/* eslint-disable max-len */
"use strict";

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

const hashValue = (value) => {
  return crypto.createHash("sha256").update(value).digest("hex");
};

const generateSecureOTP = () => {
  // Generates a cryptographically secure 6-digit OTP
  return crypto.randomInt(100000, 999999).toString();
};

const safeString = (value) => {
  if (value === null || value === undefined) return null;
  return String(value).trim();
};

// ============================================================================
// 1. NOTIFICATION FUNCTION
// ============================================================================
exports.sendUserJobNotification = functions.firestore
    .document("serviceRequests/{jobId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      if (!newData || !oldData) return null;

      const newStatus = newData.status;
      const oldStatus = oldData.status;

      if (newStatus === oldStatus) return null;

      const userId = newData.customerId;
      if (!userId) return null;

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) return null;

      const userData = userDoc.data();
      const fcmToken = userData ? userData.fcmToken : null;
      if (!fcmToken) return null;

      let title = "";
      let body = "";

      if (newStatus === "pending_approval" && oldStatus !== "pending_approval") {
        title = "New Quote Received! \uD83D\uDCB0";
        body = "An agent offered \u20b9" + newData.price + ". Check app to accept.";
      } else if (newStatus === "accepted" && oldStatus !== "accepted") {
        title = "Job Accepted! \u2705";
        body = (newData.agentName || "An Agent") + " is on the way to your location.";
      } else if (newStatus === "awaiting_payment" && oldStatus !== "awaiting_payment") {
        title = "Job Done! Please Pay \uD83D\uDCB3";
        body = "Your service is complete. Pay now to get your completion OTP.";
      } else if (newStatus === "completed" && oldStatus !== "completed") {
        title = "Job Completed \uD83C\uDF89";
        body = "Your service is fully done. Please rate your agent!";
      } else if (!newData.agentId && oldData.agentId) {
        title = "Agent Cancelled \u26A0\uFE0F";
        body = "The agent cancelled. Your job is back in the queue.";
      } else {
        return null;
      }

      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            jobId: context.params.jobId,
            status: newStatus,
          },
          android: {
            notification: {sound: "default", priority: "high"},
            priority: "high",
          },
          apns: {
            payload: {aps: {sound: "default", badge: 1}},
          },
        });
        console.log("Notification sent to user " + userId + " for status: " + newStatus);
      } catch (error) {
        if (
          error.code === "messaging/invalid-registration-token" ||
          error.code === "messaging/registration-token-not-registered"
        ) {
          console.warn("Removing stale FCM token for user " + userId);
          await admin.firestore().collection("users").doc(userId).update({fcmToken: ""});
        } else {
          console.error("Error sending notification:", error);
        }
      }

      return null;
    });

// ============================================================================
// 2. REQUEST EMAIL OTP FUNCTION (AUTH)
// ============================================================================
exports.requestEmailOTP = functions.https.onCall(async (data) => {
  const rawEmail = safeString(data.email);
  const email = rawEmail ? rawEmail.toLowerCase() : null;

  if (!email) {
    throw new functions.https.HttpsError("invalid-argument", "Email is required.");
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid email address.");
  }

  const sessionRef = admin.firestore().collection("otp_sessions").doc(email);
  const existingSession = await sessionRef.get();

  if (existingSession.exists) {
    const existingData = existingSession.data();
    const createdAtTimestamp = existingData ? existingData.createdAt : null;
    const createdAt = createdAtTimestamp ? createdAtTimestamp.toDate() : null;
    if (createdAt) {
      const diffSeconds = (new Date() - createdAt) / 1000;
      if (diffSeconds < 60) {
        throw new functions.https.HttpsError(
            "resource-exhausted",
            "Please wait " + Math.ceil(60 - diffSeconds) + " seconds before requesting a new OTP.",
        );
      }
    }
  }

  const otp = generateSecureOTP();
  const hashedOtp = hashValue(otp);

  await sessionRef.set({
    otp: hashedOtp,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    attempts: 0,
  });

  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
      <table width="100%" border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td align="center" style="padding: 40px 0;">
            <table width="100%" style="max-width: 500px; background-color: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.05); border: 1px solid #e2e8f0;">
              <tr>
                <td align="center" style="padding: 40px 40px 20px 40px;">
                  <div style="background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%); width: 60px; height: 60px; border-radius: 16px; display: inline-block; line-height: 60px; margin-bottom: 20px;">
                    <span style="color: white; font-size: 30px; font-weight: bold;">S</span>
                  </div>
                  <h1 style="margin: 0; font-size: 24px; color: #1e293b; letter-spacing: -0.5px;">ServiceSphere</h1>
                  <p style="margin: 8px 0 0 0; font-size: 14px; color: #64748b; font-weight: 500; text-transform: uppercase; letter-spacing: 1px;">Security Verification</p>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding: 0 40px 40px 40px;">
                  <p style="font-size: 16px; color: #475569; line-height: 24px; margin-bottom: 30px;">
                    Hello! Welcome to ServiceSphere. Use the code below to securely verify your account and get started.
                  </p>
                  <div style="background-color: #f1f5f9; border-radius: 12px; padding: 24px; border: 1px solid #e2e8f0;">
                    <span style="font-family: 'Courier New', Courier, monospace; font-size: 42px; font-weight: 800; color: #4F46E5; letter-spacing: 12px; margin-left: 12px;">${otp}</span>
                  </div>
                  <p style="font-size: 13px; color: #94a3b8; margin-top: 25px; line-height: 20px;">
                    This code expires in <strong>10 minutes</strong>.<br>
                    Did not request this? You can safely ignore this email.
                  </p>
                </td>
              </tr>
              <tr>
                <td style="padding: 0 40px 30px 40px;">
                  <div style="background-color: #fdf2f2; border-radius: 10px; padding: 15px; border: 1px solid #fee2e2;">
                    <p style="margin: 0; font-size: 12px; color: #991b1b; text-align: center;">
                      <strong>Security Note:</strong> We will never ask for your password or OTP over a phone call or SMS.
                    </p>
                  </div>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding: 30px; background-color: #f8fafc; border-top: 1px solid #e2e8f0;">
                  <p style="margin: 0; font-size: 12px; color: #94a3b8;">
                    ServiceSphere Rajkot \u2022 Gujarat, India
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;

  await admin.firestore().collection("mail").add({
    to: email,
    message: {
      subject: "Your ServiceSphere Code: " + otp + " \uD83D\uDEE1\uFE0F",
      html: htmlContent,
    },
  });

  return {success: true};
});

// ============================================================================
// 3. VERIFY EMAIL OTP FUNCTION (AUTH)
// ============================================================================
exports.verifyEmailOTP = functions.https.onCall(async (data) => {
  const rawEmail = safeString(data.email);
  const email = rawEmail ? rawEmail.toLowerCase() : null;
  const otp = safeString(data.otp);
  const fullName = safeString(data.fullName);
  const role = data.role || "customer";

  if (!email || !otp || !fullName) {
    throw new functions.https.HttpsError("invalid-argument", "Email, OTP, and full name are required.");
  }

  if (fullName.length < 2 || fullName.length > 50) {
    throw new functions.https.HttpsError("invalid-argument", "Full name must be between 2 and 50 characters.");
  }

  if (otp.length !== 6 || isNaN(otp)) {
    throw new functions.https.HttpsError("invalid-argument", "OTP must be a 6-digit number.");
  }

  if (role !== "customer" && role !== "agent") {
    throw new functions.https.HttpsError("invalid-argument", "Invalid role specified.");
  }

  const sessionRef = admin.firestore().collection("otp_sessions").doc(email);
  const sessionDoc = await sessionRef.get();

  if (!sessionDoc.exists) {
    throw new functions.https.HttpsError("not-found", "No OTP found for this email. Please request a new one.");
  }

  const sessionData = sessionDoc.data();

  const attempts = sessionData.attempts || 0;
  if (attempts >= 5) {
    await sessionRef.delete();
    throw new functions.https.HttpsError("resource-exhausted", "Too many failed attempts. Please request a new OTP.");
  }

  const createdAtTimestamp = sessionData.createdAt;
  const createdAt = createdAtTimestamp ? createdAtTimestamp.toDate() : null;
  if (!createdAt) {
    await sessionRef.delete();
    throw new functions.https.HttpsError("deadline-exceeded", "OTP session is invalid. Please request a new one.");
  }

  const diffMinutes = (new Date() - createdAt) / (1000 * 60);
  if (diffMinutes > 10) {
    await sessionRef.delete();
    throw new functions.https.HttpsError("deadline-exceeded", "OTP has expired. Please request a new one.");
  }

  const hashedInput = hashValue(otp);
  if (sessionData.otp !== hashedInput) {
    await sessionRef.update({attempts: admin.firestore.FieldValue.increment(1)});
    const remainingAttempts = 5 - (attempts + 1);
    throw new functions.https.HttpsError("permission-denied", "Invalid OTP. " + remainingAttempts + " attempt(s) remaining.");
  }

  await sessionRef.delete();

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(userRecord.uid, {displayName: fullName});
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      userRecord = await admin.auth().createUser({email: email, displayName: fullName});
    } else {
      console.error("Auth error:", error);
      throw new functions.https.HttpsError("internal", "Authentication error.");
    }
  }

  await admin.firestore().collection("users").doc(userRecord.uid).set({
    uid: userRecord.uid,
    displayName: fullName,
    email: email,
    role: role,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    fcmToken: "",
    isVerifiedAgent: false,
    walletBalance: 0,
    hasSeenWelcome: false,
  }, {merge: true});

  const customToken = await admin.auth().createCustomToken(userRecord.uid);
  return {token: customToken, uid: userRecord.uid};
});

// ============================================================================
// 4. PROCESS PAYMENT & CREDIT AGENT
// ============================================================================
exports.processPaymentAndCreditAgent = functions.firestore
    .document("serviceRequests/{jobId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      if (!newData || !oldData) return null;

      const newPaymentStatus = newData.paymentStatus;
      const oldPaymentStatus = oldData.paymentStatus;

      if (newPaymentStatus !== "paid" || oldPaymentStatus === "paid") {
        return null;
      }

      const jobId = context.params.jobId;
      const jobTotal = newData.price || 0;
      const agentId = newData.agentId;
      const customerId = newData.customerId;

      if (!agentId || !jobTotal) return null;

      const COMMISSION_RATE = 0.10;
      const platformCommission = Math.round(jobTotal * COMMISSION_RATE);
      const agentEarnings = jobTotal - platformCommission;

      try {
        await admin.firestore().runTransaction(async (transaction) => {
          const agentRef = admin.firestore().collection("agents").doc(agentId);
          const revenueRef = admin.firestore().collection("platform_revenue").doc(jobId);

          transaction.update(agentRef, {
            walletBalance: admin.firestore.FieldValue.increment(agentEarnings),
            totalEarnings: admin.firestore.FieldValue.increment(agentEarnings),
            completedJobs: admin.firestore.FieldValue.increment(1),
          });

          transaction.set(revenueRef, {
            jobId: jobId,
            jobTotal: jobTotal,
            platformCommission: platformCommission,
            agentEarnings: agentEarnings,
            agentId: agentId,
            customerId: customerId,
            commissionRate: COMMISSION_RATE,
            razorpayPaymentId: newData.razorpayPaymentId || "",
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        console.log("Job " + jobId + " paid. Agent earned \u20b9" + agentEarnings + ", platform earned \u20b9" + platformCommission);

        const agentDoc = await admin.firestore().collection("agents").doc(agentId).get();
        if (agentDoc.exists) {
          const agentData = agentDoc.data();
          const agentFcmToken = agentData ? agentData.fcmToken : null;
          if (agentFcmToken) {
            try {
              await admin.messaging().send({
                token: agentFcmToken,
                notification: {
                  title: "Customer Paid! \uD83D\uDCB0",
                  body: "Ask the customer for the 6-digit OTP to confirm job completion.",
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                  jobId: jobId,
                  type: "payment_received",
                },
                android: {notification: {sound: "default", priority: "high"}, priority: "high"},
                apns: {payload: {aps: {sound: "default", badge: 1}}},
              });
            } catch (fcmError) {
              console.error("Error notifying agent:", fcmError);
            }
          }
        }

        await admin.firestore().collection("walletTransactions").add({
          agentId: agentId,
          amount: agentEarnings,
          type: "credit",
          description: "Job Earnings (after 10% platform fee)",
          jobId: jobId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: "success",
        });
      } catch (error) {
        console.error("Error processing payment for job " + jobId + ":", error);
      }

      return null;
    });

// ============================================================================
// 5. ON JOB COMPLETED TRIGGER
// ============================================================================
exports.onJobCompleted = functions.firestore
    .document("serviceRequests/{jobId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      if (!newData || !oldData) return null;

      if (newData.status !== "completed" || oldData.status === "completed") {
        return null;
      }

      const jobId = context.params.jobId;
      const customerId = newData.customerId;

      try {
        await admin.firestore()
            .collection("serviceRequests")
            .doc(jobId)
            .update({
              settledAt: admin.firestore.FieldValue.serverTimestamp(),
            });

        if (customerId) {
          const userDoc = await admin.firestore().collection("users").doc(customerId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            const fcmToken = userData ? userData.fcmToken : null;
            if (fcmToken) {
              try {
                await admin.messaging().send({
                  token: fcmToken,
                  notification: {
                    title: "Job Fully Complete \uD83C\uDF89",
                    body: "Your service has been confirmed complete. Please rate your agent!",
                  },
                  data: {
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    jobId: jobId,
                    type: "job_completed",
                  },
                  android: {notification: {sound: "default"}, priority: "high"},
                  apns: {payload: {aps: {sound: "default", badge: 1}}},
                });
              } catch (fcmError) {
                console.error("Error notifying customer on completion:", fcmError);
              }
            }
          }
        }

        console.log("Job " + jobId + " fully completed and settled.");
      } catch (error) {
        console.error("Error on job completion for " + jobId + ":", error);
      }

      return null;
    });

// ============================================================================
// 6. CLEANUP EXPIRED OTP SESSIONS (CRON)
// ============================================================================
exports.cleanupExpiredOTPs = functions.pubsub
    .schedule("every 60 minutes")
    .onRun(async () => {
      const expiryTime = new Date(Date.now() - 10 * 60 * 1000);

      const expiredSessions = await admin.firestore()
          .collection("otp_sessions")
          .where("createdAt", "<", expiryTime)
          .get();

      if (expiredSessions.empty) {
        console.log("No expired OTP sessions to clean up.");
        return null;
      }

      const batch = admin.firestore().batch();
      expiredSessions.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();

      console.log("Cleaned up " + expiredSessions.size + " expired OTP session(s).");
      return null;
    });

// ============================================================================
// 7. INJECT JOB OTPS (DOUBLE OTP LOGIC)
// Triggers automatically when a new serviceRequest is created.
// Generates 6-digit Start OTP and End OTP.
// ============================================================================
exports.injectJobOTPs = functions.firestore
    .document("serviceRequests/{jobId}")
    .onCreate(async (snap, context) => {
      const startOtp = generateSecureOTP();
      const endOtp = generateSecureOTP();

      try {
        await snap.ref.update({
          startOtp: startOtp,
          endOtp: endOtp,
          paymentStatus: "pending",
        });
        console.log("Injected 6-digit Start & End OTPs for job: " + context.params.jobId);
      } catch (error) {
        console.error("Error injecting OTPs:", error);
      }
      return null;
    });

// ============================================================================
// 8. VERIFY JOB OTP (AGENT ACTION)
// Called by the Agent's Flutter app to start or complete a job.
// Takes { jobId, otp, type: 'start' | 'end' }
// ============================================================================
exports.verifyJobOTP = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
  }

  const jobId = safeString(data.jobId);
  const otp = safeString(data.otp);
  const type = safeString(data.type);

  if (!jobId || !otp || !type) {
    throw new functions.https.HttpsError("invalid-argument", "Missing parameters.");
  }

  const jobRef = admin.firestore().collection("serviceRequests").doc(jobId);
  const jobDoc = await jobRef.get();

  if (!jobDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Job not found.");
  }

  const jobData = jobDoc.data();

  // Ensure the agent calling this function is the one assigned to the job
  if (jobData.agentId !== context.auth.uid) {
    throw new functions.https.HttpsError("permission-denied", "You are not assigned to this job.");
  }

  if (type === "start") {
    if (jobData.startOtp !== otp) {
      throw new functions.https.HttpsError("invalid-argument", "Incorrect Start OTP.");
    }
    if (jobData.status !== "accepted") {
      throw new functions.https.HttpsError("failed-precondition", "Job is not in the correct state to start.");
    }
    await jobRef.update({status: "in_progress"});
    return {success: true, message: "Job started successfully."};
  } else if (type === "end") {
    if (jobData.endOtp !== otp) {
      throw new functions.https.HttpsError("invalid-argument", "Incorrect End OTP.");
    }
    if (jobData.paymentStatus !== "paid") {
      throw new functions.https.HttpsError("failed-precondition", "Payment has not been verified yet.");
    }
    await jobRef.update({status: "completed"});
    return {success: true, message: "Job completed successfully."};
  } else {
    throw new functions.https.HttpsError("invalid-argument", "Invalid OTP type.");
  }
});

// ============================================================================
// 9. RAZORPAY WEBHOOK
// Listens for 'payment.captured' events directly from Razorpay servers.
// Verifies the signature to prevent fraud, then updates paymentStatus to 'paid'.
// ============================================================================
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  // Replace this with your actual Webhook Secret from the Razorpay Dashboard
  const RAZORPAY_WEBHOOK_SECRET = "YOUR_SECRET_HERE";
  const signature = req.headers["x-razorpay-signature"];

  try {
    const expectedSignature = crypto
        .createHmac("sha256", RAZORPAY_WEBHOOK_SECRET)
        .update(req.rawBody)
        .digest("hex");

    if (expectedSignature !== signature) {
      console.error("Invalid Razorpay signature detected.");
      return res.status(400).send("Invalid signature");
    }

    const event = req.body.event;

    if (event === "payment.captured") {
      const paymentEntity = req.body.payload.payment.entity;
      const jobId = paymentEntity.notes.jobId;

      if (jobId) {
        await admin.firestore().collection("serviceRequests").doc(jobId).update({
          paymentStatus: "paid",
          razorpayPaymentId: paymentEntity.id,
        });
        console.log("Razorpay Webhook: Payment verified & updated for job " + jobId);
      } else {
        console.warn("Razorpay Webhook: Payment captured, but no jobId found in notes.");
      }
    }

    res.status(200).send("OK");
  } catch (error) {
    console.error("Razorpay Webhook Error:", error);
    res.status(500).send("Internal Server Error");
  }
});
exports.deductCashCommission = functions.firestore
    .document("serviceRequests/{jobId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      // ONLY trigger when status changes to 'completed' AND payment was 'cash'
      if (newData.status === "completed" && oldData.status !== "completed" && newData.paymentMethod === "cash") {
        const jobTotal = newData.price;
        const agentId = newData.agentId;
        const COMMISSION_RATE = 0.10; // 10% platform fee

        // Calculate what the platform is owed
        const platformCommission = Math.round(jobTotal * COMMISSION_RATE);

        // Run an atomic transaction to safely deduct the money
        await admin.firestore().runTransaction(async (transaction) => {
          const agentRef = admin.firestore().collection("agents").doc(agentId);
          const revenueRef = admin.firestore().collection("platformRevenue").doc();

          // 1. Deduct commission from Agent's Wallet
          transaction.update(agentRef, {
            walletBalance: admin.firestore.FieldValue.increment(-platformCommission),
            completedJobs: admin.firestore.FieldValue.increment(1),
          });

          // 2. Add ledger entry to agent's history (so they see the deduction)
          const walletTransactionRef = admin.firestore().collection("walletTransactions").doc();
          transaction.set(walletTransactionRef, {
            agentId: agentId,
            amount: -platformCommission, // Negative because it's a deduction
            type: "debit",
            description: "Platform Commission (Cash Job)",
            jobId: context.params.jobId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

          // 3. Log your Admin HQ Revenue!
          transaction.set(revenueRef, {
            jobId: context.params.jobId,
            jobTotal: jobTotal,
            platformCommission: platformCommission,
            paymentMethod: "cash",
            agentId: agentId,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        console.log(`Successfully deducted ₹${platformCommission} from Agent ${agentId}`);
        return null;
      }
      return null;
    });
