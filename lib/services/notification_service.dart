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
import '../models/survey_model.dart';
import '../screens/survey_detail_screen.dart';
import 'choriste_service.dart';
import 'survey_service.dart';

// ─────────────────────────────────────────────────────────────
// Handlers top-level obligatoires (isolat background)
// ─────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) print('[FCM BG] ${message.notification?.title}');
  // NOTE : en background, Android affiche automatiquement la notif système.
  // Pas besoin de flutter_local_notifications ici.
}

@pragma('vm:entry-point')
void _localNotifBackgroundHandler(NotificationResponse response) {
  NotificationService.handleNotificationTapFromPayload(response.payload);
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
  static final Set<String> _notifiedSurveyIdsSession = {};

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
        handleNotificationTapFromPayload(r.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _localNotifBackgroundHandler,
    );

    // 3. Canal Android haute importance
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'cso_high_importance',
        'Notifications CSO',
        description: 'Rappels et alertes du Carthage Symphony Orchestra',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Permission notifications système (Android 13+)
    final androidNotifGranted =
        await androidPlugin?.requestNotificationsPermission();
    if (kDebugMode) {
      print('[FCM] Permission Android système: $androidNotifGranted');
    }

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
    // Gère aussi les data-only messages (sans notification block)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print(
          '[FCM FG] ${message.notification?.title ?? message.data['type']}',
        );
        print('[FCM FG] data: ${message.data}');
      }

      final parsed = _parseNotificationContent(message);
      _showLocalNotification(
        title: parsed.title,
        body: parsed.body,
        payload: _encodePayload(message.data),
      );
    });

    // Tap sur notif (app en background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationTap(message.data);
    });

    // App fermée → ouverte via tap sur notification
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          handleNotificationTap(message.data);
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
      if (kDebugMode) {
        print('[FCM] ✅ Token FCM envoyé (${token.substring(0, 20)}…)');
      }
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur saveTokenAfterLogin: $e');
    }
  }

  /// Alias utilisé dans AuthProvider.login()
  static Future<void> refreshAndSaveToken() => saveTokenAfterLogin();

  /// À appeler au logout pour stopper les notifications.
  /// ✅ Ne JAMAIS appeler deleteToken() — cela invalide le token Firebase
  /// et cause NotRegistered lors du prochain envoi.
  /// Alerte locale si de nouveaux sondages en attente (secours si FCM absent).
  static Future<void> notifyNewPendingSurveys(
    List<({String id, String titre})> pending,
  ) async {
    if (!_initialized || pending.isEmpty) return;

    final fresh = pending
        .where((s) => !_notifiedSurveyIdsSession.contains(s.id))
        .toList();
    if (fresh.isEmpty) return;

    for (final s in fresh) {
      _notifiedSurveyIdsSession.add(s.id);
    }

    final title = fresh.length == 1
        ? 'Nouveau sondage'
        : '${fresh.length} sondages à répondre';
    final body = fresh.length == 1
        ? '« ${fresh.first.titre} » — votre réponse est attendue'
        : fresh.map((s) => '« ${s.titre} »').take(2).join('\n');

    await _showLocalNotification(
      title: title,
      body: body,
      payload: _encodePayload({
        'type': 'new_survey',
        'surveyId': fresh.first.id,
      }),
    );
    if (kDebugMode) {
      print('[FCM] Alerte locale sondage(s): ${fresh.map((s) => s.titre).join(', ')}');
    }
  }

  static Future<void> deleteTokenOnLogout() async {
    try {
      final jwt = await _storage.read(key: 'token');
      if (jwt != null) {
        // Envoyer token vide → backend fait $unset { fcmToken }
        await ChoristeService().saveFcmToken('');
        if (kDebugMode) print('[FCM] Token dissocié du compte ✅');
      }
      // ✅ PAS de _fcm.deleteToken() ici
    } catch (e) {
      if (kDebugMode) print('[FCM] Erreur deleteTokenOnLogout: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION DEPUIS UNE NOTIFICATION
  // ─────────────────────────────────────────────────────────────

  static ({String title, String body}) _parseNotificationContent(
    RemoteMessage message,
  ) {
    final type = message.data['type'] ?? '';
    final notif = message.notification;

    if (notif != null && notif.title != null && notif.title!.isNotEmpty) {
      return (
        title: notif.title!,
        body: notif.body ?? '',
      );
    }

    switch (type) {
      case 'chef_message':
        final sender = message.data['senderName'] ?? 'Votre chef de pupitre';
        return (
          title: 'Message de $sender',
          body: message.data['content'] ?? 'Nouveau message de $sender',
        );
      case 'new_survey':
        return (
          title: 'Nouveau sondage',
          body: message.data['surveyTitle'] ??
              'Un sondage vous est destiné — votre réponse est attendue',
        );
      default:
        return (title: 'CSO', body: 'Vous avez une nouvelle notification');
    }
  }

  static String _encodePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return '';
    return data.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  static Map<String, String> _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    if (!raw.contains('=')) return {'type': raw};
    final map = <String, String>{};
    for (final part in raw.split('&')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      map[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return map;
  }

  @pragma('vm:entry-point')
  static void handleNotificationTapFromPayload(String? payload) {
    handleNotificationTap(_decodePayload(payload));
  }

  @pragma('vm:entry-point')
  static void handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (kDebugMode) print('[FCM] Tap → navigation: $type');

    switch (type) {
      // ── Répétitions ──
      case 'new_repetition':
      case 'repetition_updated':
      case 'repetition_cancelled':
      case 'repetition_reminder_2h':
      case 'repetition_reminder_10min':
      case 'reminder_day_before':
      case 'reminder_2h':
      case 'reminder_10min':
      case 'choriste_reminder':
      case 'presence_updated':
        navigator.pushNamed('/repetitions');
        break;

      // ── Concerts ──
      case 'new_concert':
      case 'concert_updated':
      case 'concert_cancelled':
        navigator.pushNamed('/concerts');
        break;

      // ── Messages chef de pupitre ──
      case 'chef_message':
        navigator.pushNamed('/messages');
        break;

      // ── Sondages ──
      case 'new_survey':
      case 'survey_activated':
        final surveyId = data['surveyId']?.toString();
        if (surveyId != null && surveyId.isNotEmpty) {
          _openSurveyDetail(navigator, surveyId);
        } else {
          navigator.pushNamed('/sondages');
        }
        break;

      // ── Validation liste présences ──
      case 'presence_list_validated':
        navigator.pushNamed('/repetitions');
        break;

      default:
        navigator.pushNamed('/repetitions');
    }
  }

  static Future<void> _openSurveyDetail(
    NavigatorState navigator,
    String surveyId,
  ) async {
    try {
      final raw = await SurveyService().getSurveyById(surveyId);
      final survey = SurveyModel.fromJson(raw);
      navigator.push(
        MaterialPageRoute(builder: (_) => SurveyDetailScreen(survey: survey)),
      );
    } catch (e) {
      if (kDebugMode) print('[FCM] Ouverture sondage échouée: $e');
      navigator.pushNamed('/sondages');
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
}
