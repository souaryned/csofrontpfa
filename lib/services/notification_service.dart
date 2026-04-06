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
  // NOTE : en background, Android affiche automatiquement la notif système.
  // Pas besoin de flutter_local_notifications ici.
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
    // ✅ FIX : gérer aussi les data-only messages (sans notification block)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) print('[FCM] Foreground: ${message.notification?.title ?? message.data['type']}');
      final notif = message.notification;
      if (notif != null) {
        // Message avec bloc notification
        _showLocalNotification(
          title: notif.title ?? '',
          body: notif.body ?? '',
          payload: message.data['type'] ?? '',
        );
      } else if (message.data.isNotEmpty) {
        // ✅ Data-only message → construire la notif manuellement
        final type = message.data['type'] ?? '';
        String title = 'CSO';
        String body  = 'Vous avez un nouveau message';
        if (type == 'chef_message') {
          final sender = message.data['senderName'] ?? 'Votre chef de pupitre';
          body = message.data['content'] ?? 'Nouveau message de $sender';
          title = 'Message de $sender';
        }
        _showLocalNotification(title: title, body: body, payload: type);
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
      // ── Répétitions (existant) ──
      case 'new_repetition':
      case 'repetition_updated':
      case 'repetition_cancelled':
      case 'repetition_reminder_2h':
      case 'repetition_reminder_10min':
      case 'reminder_day_before':
      case 'reminder_2h':
      case 'reminder_10min':
      case 'presence_updated':        // ✅ choriste notifié d'une modif de présence
        navigator.pushNamed('/repetitions');
        break;

      // ── Concerts (existant) ──
      case 'new_concert':
        navigator.pushNamed('/concerts');
        break;

      // ── Messages chef de pupitre ──
      case 'chef_message':            // ✅ choriste reçoit un message de son chef
        navigator.pushNamed('/messages');
        break;

      // ── Validation liste présences (chef de chœur / admin) ──
      case 'presence_list_validated': // ✅ chef de chœur notifié qu'une liste est validée
        navigator.pushNamed('/repetitions');
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
        if (kDebugMode) print('[FCM] Token envoyé ✅ : ${token.substring(0, 20)}...');
        await ChoristeService().saveFcmToken(token);
      } else {
        if (kDebugMode) print('[FCM] ⚠️ Token null — vérifier Firebase config');
      }
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur _saveTokenIfLoggedIn: $e');
    }
  }

  /// Appeler après LOGIN — associe le token de l'appareil au compte connecté
  static Future<void> refreshAndSaveToken() async {
    try {
      // ✅ Pas de deleteToken — on récupère le token existant de l'appareil
      // et on l'associe au nouveau compte en BDD
      final token = await _fcm.getToken();
      if (token != null) {
        if (kDebugMode) print('[FCM] Token associé au compte après login ✅');
        await ChoristeService().saveFcmToken(token);
      }
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur refreshAndSaveToken: $e');
    }
  }

  /// Appeler après LOGOUT — dissocie le token du compte en BDD
  /// ✅ Ne JAMAIS appeler deleteToken() — cela invalide le token Firebase
  /// et cause NotRegistered lors du prochain envoi
  static Future<void> clearTokenOnLogout() async {
    try {
      final jwt = await _storage.read(key: 'token');
      if (jwt != null) {
        // Envoyer token vide → backend fait $unset { fcmToken }
        await ChoristeService().saveFcmToken('');
        if (kDebugMode) print('[FCM] Token dissocié du compte ✅');
      }
      // ✅ PAS de _fcm.deleteToken() ici
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur clearTokenOnLogout: $e');
    }
  }
}