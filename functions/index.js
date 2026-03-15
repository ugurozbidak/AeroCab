const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggers when a reservation document is updated.
 * Checks if the ride status has changed from 'created' to 'accepted'.
 * If so, sends a notification to the passenger.
 */
exports.notifyOnRideAccepted = functions.region("us-central1") // Specify a region
    .firestore
    .document("reservations/{reservationId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      // Proceed only if the status changed from 'created' to 'accepted'
      if (oldData.status !== "created" || newData.status !== "accepted") {
        return null;
      }

      const passengerId = newData.passenger_id;
      if (!passengerId) {
        functions.logger.error("Passenger ID is missing.");
        return null;
      }

      functions.logger.log(`Ride accepted for passenger: ${passengerId}`);

      try {
        // Get the passenger's user document to find their FCM token
        const passengerDoc = await admin.firestore()
            .collection("users").doc(passengerId).get();

        if (!passengerDoc.exists) {
          functions.logger.error(`Passenger document not found for ID: ${passengerId}`);
          return null;
        }

        const fcmToken = passengerDoc.data().fcmToken;
        if (!fcmToken) {
          functions.logger.warn(`FCM token not found for passenger: ${passengerId}`);
          return null;
        }

        // Construct the notification payload
        const payload = {
          notification: {
            title: "Your AeroCab Ride is Accepted!",
            body: "A driver is on the way. Please be ready.",
            sound: "default",
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "/ride-details", // Example screen to navigate to
            reservationId: context.params.reservationId,
          },
        };

        // Send the notification to the passenger's device
        const response = await admin.messaging().sendToDevice(fcmToken, payload);
        functions.logger.log("Successfully sent notification:", response);
        return response;
      } catch (error) {
        functions.logger.error("Error sending notification:", error);
        return null;
      }
    });
