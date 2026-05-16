// ============================================================
// notification_service.dart
// Compatible : flutter_local_notifications ^21.0.0
// ============================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'choriste_service.dart';

// ─────────────────────────────────────────────────────────────
// Handlers top-level obligatoires (isolat background)
// ─────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) print('[FCM BG] ${message.notification?.title}');
}

@pragma('vm:entry-point')
void _localNotifBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationTap(response.payload);
}

// ─────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Clé de navigation globale — branchée sur MaterialApp.navigatorKey
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;

  // ─────────────────────────────────────────────────────────────
  // INITIALISATION
  // Appelée dans main(), avant runApp(), même sans connexion.
  // ─────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. Handler background FCM
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. flutter_local_notifications (v21 : paramètre nommé "settings:")
    await _localNotif.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        handleNotificationTap(r.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _localNotifBackgroundHandler,
    );

    // 3. Canal Android haute importance
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'cso_high_importance',
            'Notifications CSO',
            description: 'Rappels et alertes du Carthage Symphony Orchestra',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    // 4. Permissions FCM
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      print('[FCM] Permission: ${settings.authorizationStatus}');
    }

    // 5. Écouter les messages
    _setupListeners();

    _initialized = true;
    if (kDebugMode) print('[FCM] ✅ Initialisé.');
  }

  // ─────────────────────────────────────────────────────────────
  // LISTENERS FCM
  // ─────────────────────────────────────────────────────────────

  static void _setupListeners() {
    // Message en foreground → afficher notification locale
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('[FCM FG] ${message.notification?.title}');
        print('[FCM FG] data: ${message.data}');
      }
      final notif = message.notification;
      if (notif != null) {
        _showLocalNotification(
          title: notif.title ?? '',
          body: notif.body ?? '',
          payload: message.data['type'] ?? '',
        );
      }
    });

    // Tap sur notif (app en background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationTap(message.data['type']);
    });

    // App fermée → ouverte via tap sur notification
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          handleNotificationTap(message.data['type']);
        });
      }
    });

    // Token FCM rafraîchi automatiquement par Firebase
    // → renvoyer immédiatement au backend
    _fcm.onTokenRefresh.listen((String newToken) async {
      if (kDebugMode) print('[FCM] Token rafraîchi automatiquement.');
      final jwt = await _storage.read(key: 'token');
      if (jwt != null) {
        await ChoristeService().saveFcmToken(newToken);
        if (kDebugMode) print('[FCM] ✅ Nouveau token envoyé.');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // GESTION DU TOKEN FCM
  // ─────────────────────────────────────────────────────────────

  /// À appeler après login ET au démarrage si connecté.
  /// Garantit que le backend a toujours le bon token FCM.
  static Future<void> saveTokenAfterLogin() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        if (kDebugMode) print('[FCM] ⚠️ Aucun token FCM.');
        return;
      }
      await ChoristeService().saveFcmToken(token);
      if (kDebugMode) print('[FCM] ✅ Token FCM envoyé.');
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur saveTokenAfterLogin: $e');
    }
  }

  /// Alias utilisé dans AuthProvider.login()
  static Future<void> refreshAndSaveToken() => saveTokenAfterLogin();

  /// À appeler au logout pour stopper les notifications.
  static Future<void> deleteTokenOnLogout() async {
    try {
      final jwt = await _storage.read(key: 'token');
      if (jwt != null) {
        // Envoyer null au backend → plus de notifications pour ce device
        await ChoristeService().saveFcmToken('');
      }
      await _fcm.deleteToken();
      if (kDebugMode) print('[FCM] Token supprimé au logout.');
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur deleteTokenOnLogout: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICATION LOCALE (foreground)
  // v21 : show() → paramètres nommés id/title/body/notificationDetails/payload
  // ─────────────────────────────────────────────────────────────

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    await _localNotif.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cso_high_importance',
          'Notifications CSO',
          channelDescription:
              'Rappels et alertes du Carthage Symphony Orchestra',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION DEPUIS UNE NOTIFICATION
  // ─────────────────────────────────────────────────────────────

  @pragma('vm:entry-point')
  static void handleNotificationTap(String? type) {
    if (type == null || type.isEmpty) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (kDebugMode) print('[FCM] Navigation → $type');

    switch (type) {
      case 'new_repetition':
      case 'repetition_updated':
      case 'repetition_cancelled':
      case 'reminder_day_before':
      case 'reminder_2h':
      case 'reminder_10min':
      case 'choriste_reminder':
        nav.pushNamed('/repetitions');
        break;
      case 'new_concert':
      case 'concert_updated':
      case 'concert_cancelled':
        nav.pushNamed('/concerts');
        break;
      default:
        nav.pushNamed('/repetitions');
    }
  }
}
