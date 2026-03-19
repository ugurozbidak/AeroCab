import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background mesajları için top-level handler (Flutter zorunluluğu)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('[FCM] Background message: ${message.messageId}', name: 'Notification');
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
  'high_importance_channel',
  'Önemli Bildirimler',
  description: 'Yolculuk durumu bildirimleri.',
  importance: Importance.max,
);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Navigator key — main.dart'tan set edilir
  static GlobalKey<NavigatorState>? navigatorKey;

  // ── Başlatma ────────────────────────────────────────────────────────────────
  Future<void> init(String userId) async {
    // İzin iste
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    log('[FCM] Permission: ${settings.authorizationStatus}',
        name: 'Notification');

    // iOS: foreground'da da bildirim göster
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android: bildirim kanalı oluştur
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highImportanceChannel);

    // Local notifications başlat
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Token al ve kaydet
    await _refreshAndSaveToken(userId);

    // Token yenilenirse güncelle
    _messaging.onTokenRefresh.listen((token) {
      _saveToken(userId, token);
    });

    // Foreground mesaj dinleyici
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Bildirime tıklanarak açıldığında (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Uygulama kapalıyken bildirime tıklanarak açıldığında
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Kısa gecikme: widget tree hazır olsun
      await Future.delayed(const Duration(milliseconds: 500));
      _onNotificationTap(initialMessage);
    }
  }

  // ── Token yönetimi ──────────────────────────────────────────────────────────
  Future<void> _refreshAndSaveToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(userId, token);
        log('[FCM] Token kaydedildi', name: 'Notification');
      }
    } catch (e) {
      log('[FCM] Token alınamadı: $e', name: 'Notification');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      log('[FCM] Token kaydedilemedi: $e', name: 'Notification');
    }
  }

  // Logout: token'ı Firestore'dan ve cihazdan sil
  Future<void> clearToken(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': FieldValue.delete()});
      await _messaging.deleteToken();
      log('[FCM] Token temizlendi', name: 'Notification');
    } catch (e) {
      log('[FCM] Token temizlenemedi: $e', name: 'Notification');
    }
  }

  // ── Foreground mesaj ────────────────────────────────────────────────────────
  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    log('[FCM] Foreground: ${notification.title}', name: 'Notification');

    flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          highImportanceChannel.id,
          highImportanceChannel.name,
          channelDescription: highImportanceChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['screen'],
    );
  }

  // ── Bildirime tıklanma (FCM) ────────────────────────────────────────────────
  void _onNotificationTap(RemoteMessage message) {
    log('[FCM] Tap: ${message.data}', name: 'Notification');
    _navigate(message.data['screen']);
  }

  // ── Bildirime tıklanma (local notification) ─────────────────────────────────
  void _onLocalNotificationTap(NotificationResponse response) {
    log('[FCM] Local tap: ${response.payload}', name: 'Notification');
    _navigate(response.payload);
  }

  // ── Navigasyon ──────────────────────────────────────────────────────────────
  void _navigate(String? screen) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    // Tüm bildirimler home'a yönlendiriyor;
    // aktif yolculuk stream'i doğru durumu zaten gösteriyor.
    navigator.pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
