import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'choriste_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) print('[FCM] Background: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // ✅ Clé de navigation globale (à passer dans MaterialApp)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Init avec callback tap (foreground)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    // Canal Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'cso_high_importance',
      'Notifications CSO',
      description: 'Notifications importantes de CSO',
      importance: Importance.high,
      playSound: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    await _saveTokenIfLoggedIn();

    _fcm.onTokenRefresh.listen((newToken) async {
      final jwt = await _storage.read(key: 'token');
      if (jwt != null) await ChoristeService().saveFcmToken(newToken);
    });

    // Foreground → notif locale visible
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('[FCM] Foreground: ${message.notification?.title}');
      final notif = message.notification;
      if (notif != null) {
        _showLocalNotification(
          title: notif.title ?? '',
          body: notif.body ?? '',
          payload: message.data['type'] ?? '',
        );
      }
    });

    // Background → tap sur la notif système
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data['type']);
    });

    // App fermée → tap qui l'ouvre
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage.data['type']);
      });
    }
  }

  // ✅ Navigation selon le type de la notification
  static void _handleNotificationTap(String? type) {
    if (type == null) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (kDebugMode) print('[FCM] Tap → navigation: $type');

    switch (type) {
      case 'new_repetition':
        navigator.pushNamed('/repetitions');
        break;
      case 'new_concert':
        navigator.pushNamed('/concerts');
        break;
      default:
        navigator.pushNamed('/repetitions');
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cso_high_importance',
      'Notifications CSO',
      channelDescription: 'Notifications importantes de CSO',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> _saveTokenIfLoggedIn() async {
    try {
      final jwt = await _storage.read(key: 'token');
      if (jwt == null) {
        if (kDebugMode) print('[FCM] Non connecté → token non envoyé');
        return;
      }
      final token = await _fcm.getToken();
      if (token != null) {
        if (kDebugMode) print('[FCM] Token obtenu ✅');
        await ChoristeService().saveFcmToken(token);
      }
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur: $e');
    }
  }

  static Future<void> refreshAndSaveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        if (kDebugMode) print('[FCM] Token envoyé au backend ✅');
        await ChoristeService().saveFcmToken(token);
      }
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur: $e');
    }
  }
}