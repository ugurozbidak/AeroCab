const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

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
            sound: "default",
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

// ── Yeni rezervasyon: online sürücülere bildir ────────────────────────────────
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

      const notifications = driversSnap.docs.map((doc) =>
        sendNotification(
            doc.id,
            "Yeni Yolculuk Talebi",
            `${pickupAddress} → ${dropoffAddress}`,
            { reservationId, screen: "home" },
        ),
      );

      await Promise.all(notifications);
      return null;
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
        // Atanmış sürücü varsa bildir (yolcu iptal etti)
        if (driverId) {
          await sendNotification(
              driverId,
              "Rezervasyon İptal Edildi",
              "Yolcu rezervasyonu iptal etti.",
              baseData,
          );
        }
        // Yolcuyu her zaman bildir (sürücü iptal ettiyse veya sistem iptali)
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
