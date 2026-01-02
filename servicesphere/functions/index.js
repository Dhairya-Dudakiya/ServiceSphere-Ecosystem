const functions = require("firebase-functions/v1"); // Explicitly use v1
const admin = require("firebase-admin");
admin.initializeApp();

// We use the standard (Gen 1) syntax here to avoid Eventarc permission errors
exports.sendUserJobNotification = functions.firestore
    .document("serviceRequests/{jobId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      if (!newData || !oldData) {
        console.log("No data found");
        return null;
      }

      // 1. Get Status
      const newStatus = newData.status;
      const oldStatus = oldData.status;

      // 2. Get User Details
      const userId = newData.customerId;
      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(userId)
          .get();

      // 3. Get FCM Token
      const fcmToken = userDoc.data().fcmToken;

      if (!fcmToken) {
        console.log("No FCM Token for user:", userId);
        return null;
      }

      let title = "";
      let body = "";

      // --- LOGIC: DETERMINE NOTIFICATION TYPE ---

      // eslint-disable-next-line max-len
      if (newStatus === "pending_approval" && oldStatus !== "pending_approval") {
      // SCENARIO 1: Quote Received
        title = "New Quote Received! 💰";
        body = `An agent offered ₹${newData.price}. Check app to accept.`;
      } else if (newStatus === "accepted" && oldStatus !== "accepted") {
      // SCENARIO 2: Job Accepted
        title = "Job Accepted! ✅";
        body = `${newData.agentName || "An Agent"} is active on your job.`;
      } else if (newStatus === "completed" && oldStatus !== "completed") {
      // SCENARIO 3: Job Completed
        title = "Job Completed 🎉";
        body = "Your service is done. Please rate the agent!";
      } else if (!newData.agentId && oldData.agentId) {
      // SCENARIO 4: Agent Cancelled
        title = "Agent Cancelled ⚠️";
        body = "The agent cancelled. Your job is back in the queue.";
      } else {
        return null;
      }

      // 4. Send Notification
      const payload = {
        notification: {
          title: title,
          body: body,
          sound: "default",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          jobId: context.params.jobId,
        },
      };

      try {
        await admin.messaging().sendToDevice(fcmToken, payload);
        console.log("Notification sent to:", userId);
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    });
