const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { CloudTasksClient } = require("@google-cloud/tasks");

admin.initializeApp();

const PROJECT_ID = "aerocab-5d474";
const LOCATION = "europe-west1";
const QUEUE_NAME = "ride-offer-queue";
const OFFER_TIMEOUT_SECONDS = 30;
const FUNCTION_URL = `https://${LOCATION}-${PROJECT_ID}.cloudfunctions.net/processOfferExpired`;

// ── Yardımcı: FCM gönder ─────────────────────────────────────────────────────
async function sendNotification(userId, title, body, data = {}) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            sound: "ride_alert.caf",
            badge: 1,
            "content-available": 1,
          },
        },
      },
      android: {
        priority: "high",
        notification: { sound: "default", channelId: "high_importance_channel" },
      },
    });

    functions.logger.log(`Notification sent to ${userId}: ${title}`);
  } catch (error) {
    functions.logger.error(`Error sending notification to ${userId}:`, error);
  }
}

// ── Yardımcı: Belirli sürücüye teklif gönder ─────────────────────────────────
async function offerRideToDriver(reservationId, driverId, pickupAddress, dropoffAddress) {
  await admin.firestore().collection("reservations").doc(reservationId).update({
    current_offer_driver: driverId,
    offer_started_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  await sendNotification(
    driverId,
    "Yeni Yolculuk Talebi",
    `${pickupAddress} → ${dropoffAddress}`,
    { reservationId, screen: "home" },
  );
}

// ── Yardımcı: Cloud Task planla (30 saniye sonra) ─────────────────────────────
async function scheduleOfferExpiry(reservationId) {
  try {
    const client = new CloudTasksClient();
    const parent = client.queuePath(PROJECT_ID, LOCATION, QUEUE_NAME);

    const task = {
      httpRequest: {
        httpMethod: "POST",
        url: FUNCTION_URL,
        headers: { "Content-Type": "application/json" },
        body: Buffer.from(JSON.stringify({ reservationId })).toString("base64"),
      },
      scheduleTime: {
        seconds: Math.floor(Date.now() / 1000) + OFFER_TIMEOUT_SECONDS,
      },
    };

    await client.createTask({ parent, task });
    functions.logger.log(`Offer expiry task scheduled for ${reservationId}`);
  } catch (error) {
    functions.logger.error(`Failed to schedule task for ${reservationId}:`, error);
  }
}

// ── Yeni rezervasyon: sürücü sırası oluştur ve ilkine teklif et ───────────────
exports.onReservationCreated = functions
    .region("europe-west1")
    .firestore.document("reservations/{reservationId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      if (data.status !== "created") return null;

      const reservationId = context.params.reservationId;
      const pickupAddress = data.pickup_address || "Belirtilmemiş";
      const dropoffAddress = data.dropoff_address || "Belirtilmemiş";

      // Online sürücüleri bul
      const driversSnap = await admin
          .firestore()
          .collection("driver_locations")
          .where("isOnline", "==", true)
          .get();

      if (driversSnap.empty) return null;

      const driverIds = driversSnap.docs.map((doc) => doc.id);

      // Sürücü sırasını rezervasyona kaydet
      await snap.ref.update({
        driver_queue: driverIds,
        offer_index: 0,
        current_offer_driver: null,
      });

      // İlk sürücüye teklif et
      await offerRideToDriver(reservationId, driverIds[0], pickupAddress, dropoffAddress);

      // 30 saniyelik zamanlayıcı başlat
      await scheduleOfferExpiry(reservationId);

      return null;
    });

// ── Cloud Task: teklif süresi doldu, sıradaki sürücüye geç ───────────────────
exports.processOfferExpired = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      try {
        const { reservationId } = req.body;
        if (!reservationId) {
          res.status(400).send("Missing reservationId");
          return;
        }

        const reservationRef = admin.firestore().collection("reservations").doc(reservationId);
        const reservationDoc = await reservationRef.get();

        if (!reservationDoc.exists) {
          res.status(200).send("Reservation not found");
          return;
        }

        const data = reservationDoc.data();

        // Zaten kabul/iptal edildiyse dur
        if (data.status !== "created") {
          res.status(200).send("Reservation already handled");
          return;
        }

        const driverQueue = data.driver_queue || [];
        const currentIndex = data.offer_index || 0;
        const nextIndex = currentIndex + 1;

        if (nextIndex >= driverQueue.length) {
          // Sırada sürücü kalmadı
          functions.logger.log(`No more drivers for reservation ${reservationId}`);
          await reservationRef.update({
            current_offer_driver: null,
          });
          res.status(200).send("No more drivers in queue");
          return;
        }

        const nextDriverId = driverQueue[nextIndex];
        const pickupAddress = data.pickup_address || "Belirtilmemiş";
        const dropoffAddress = data.dropoff_address || "Belirtilmemiş";

        // offer_index güncelle
        await reservationRef.update({ offer_index: nextIndex });

        // Sıradaki sürücüye teklif et
        await offerRideToDriver(reservationId, nextDriverId, pickupAddress, dropoffAddress);

        // Yeni 30 saniyelik task planla
        await scheduleOfferExpiry(reservationId);

        functions.logger.log(`Offer moved to driver ${nextDriverId} for reservation ${reservationId}`);
        res.status(200).send("Offered to next driver");
      } catch (error) {
        functions.logger.error("processOfferExpired error:", error);
        res.status(500).send("Internal error");
      }
    });

// ── Rezervasyon durum değişikliği ────────────────────────────────────────────
exports.onReservationStatusChanged = functions
    .region("europe-west1")
    .firestore.document("reservations/{reservationId}")
    .onUpdate(async (change, context) => {
      const newData = change.after.data();
      const oldData = change.before.data();

      const oldStatus = oldData.status;
      const newStatus = newData.status;

      if (oldStatus === newStatus) return null;

      const passengerId = newData.passenger_id;
      const driverId = newData.driver_id;
      const reservationId = context.params.reservationId;

      const baseData = { reservationId, screen: "home" };

      // ── created → accepted: Sürücü kabul etti ──────────────────────────────
      if (oldStatus === "created" && newStatus === "accepted") {
        await sendNotification(
            passengerId,
            "Sürücünüz Atandı",
            "Sürücünüz yola çıkıyor. Hazır olun!",
            baseData,
        );
        return null;
      }

      // ── accepted → heading_to_pickup: Sürücü alınış noktasına geliyor ──────
      if (oldStatus === "accepted" && newStatus === "heading_to_pickup") {
        await sendNotification(
            passengerId,
            "Sürücünüz Geliyor",
            "Sürücünüz alınış noktasına doğru yola çıktı.",
            baseData,
        );
        return null;
      }

      // ── heading_to_pickup → on_route: Yolculuk başladı ────────────────────
      if (oldStatus === "heading_to_pickup" && newStatus === "on_route") {
        await sendNotification(
            passengerId,
            "Yolculuğunuz Başladı",
            "İyi yolculuklar!",
            baseData,
        );
        return null;
      }

      // ── on_route → completed: Tamamlandı ──────────────────────────────────
      if (oldStatus === "on_route" && newStatus === "completed") {
        await sendNotification(
            passengerId,
            "Yolculuk Tamamlandı",
            "Umarız güzel bir yolculuktu. Puanlamayı unutmayın!",
            { ...baseData, screen: "home" },
        );
        return null;
      }

      // ── * → cancelled: İptal ──────────────────────────────────────────────
      if (newStatus === "cancelled") {
        if (driverId) {
          await sendNotification(
              driverId,
              "Rezervasyon İptal Edildi",
              "Yolcu rezervasyonu iptal etti.",
              baseData,
          );
        }
        if (passengerId && driverId) {
          await sendNotification(
              passengerId,
              "Rezervasyon İptal Edildi",
              "Sürücünüz rezervasyonu iptal etti. Yeni bir rezervasyon oluşturabilirsiniz.",
              baseData,
          );
        }
        return null;
      }

      return null;
    });
