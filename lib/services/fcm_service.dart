import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase_options.dart';
import 'navigation_service.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// ===========================================================
  /// BACKGROUND HANDLER
  /// ===========================================================
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("🌙 Background: ${message.data}");
  }

  /// ===========================================================
  /// INITIALIZE
  /// ===========================================================
  static Future<void> initialize() async {
    await _initLocalNotif();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint("❌ User menolak izin notifikasi");
      return;
    }

    // Token awal
    final token = await _messaging.getToken();
    if (token != null) _saveToken(token);

    // Token refresh
    _messaging.onTokenRefresh.listen(_saveToken);

    // Foreground
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background → klik notif
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleNavigation(msg.data);
    });

    // Terminated → klik notif
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleNavigation(initial.data);
  }

  /// ===========================================================
  /// LOCAL NOTIFICATION
  /// ===========================================================
  static Future<void> _initLocalNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _localNotif.initialize(settings);

    const channel = AndroidNotificationChannel(
      'main_channel',
      'App Notifications',
      importance: Importance.max,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _showLocalNotification(RemoteMessage msg) async {
    final title = msg.notification?.title ?? msg.data["title"] ?? "Notifikasi";
    final body = msg.notification?.body ?? msg.data["body"] ?? "";

    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'App Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _localNotif.show(
      msg.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: "${msg.data}",
    );
  }

  /// ===========================================================
  /// SAVE TOKEN
  /// ===========================================================
  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "fcmTokens": FieldValue.arrayUnion([token]),
      "updatedAt": DateTime.now(),
    }, SetOptions(merge: true));

    debugPrint("📌 Token saved: $token");
  }

  /// ===========================================================
  /// DEEP LINK ROUTING
  /// ===========================================================
  static void _handleNavigation(Map<String, dynamic> data) {
    debugPrint("➡ Data Click Notif: $data");

    final route = data["route"];
    if (route == null) return;

    final productId = data["productId"];
    final orderId = data["orderId"];

    navigatorKey.currentState?.pushNamed(
      route,
      arguments: productId ?? orderId,
    );
  }
}
