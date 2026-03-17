import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications(String userId) async {
    // iOS için bildirim izinlerini isteme
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Cihazın FCM token'ını al ve veritabanına kaydet
    // iOS'ta APNS token henüz hazır olmayabilir, hata durumunda atla
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      log('FCM Token: $fcmToken', name: 'NotificationService');
      if (fcmToken != null) {
        await _saveTokenToDatabase(userId, fcmToken);
        // Token yenilendiğinde veritabanını güncelle
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          _saveTokenToDatabase(userId, newToken);
        });
      }
    } catch (e) {
      log('FCM token alınamadı: $e', name: 'NotificationService');
    }

    // Android için bildirim kanalı oluşturma
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Uygulama ön plandayken gelen bildirimleri dinleme
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        // 32-bit sınırları içinde benzersiz bir ID oluşturma
        final int notificationId = DateTime.now().millisecondsSinceEpoch
            .remainder(100000);

        _flutterLocalNotificationsPlugin.show(
          id: notificationId,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log(
        'A new onMessageOpenedApp event was published!',
        name: 'NotificationService',
      );
    });
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      log('Error saving FCM token: $e', name: 'NotificationService');
    }
  }
}
