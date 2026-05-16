import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ChoristeService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authHeaders() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Répétitions ──────────────────────────────────────────────

  Future<List<dynamic>> getRepetitions() async {
    final response = await _dio.get(
      '/repetition',
      options: await _authHeaders(),
    );
    return response.data;
  }

  /// Mark presence — may throw DioException with status 403 and
  /// code 'OUTSIDE_REPETITION_WINDOW' if outside the time window.
  Future<void> markRepetitionPresence(String repetitionId) async {
    await _dio.post(
      '/repetition/$repetitionId/presence',
      options: await _authHeaders(),
    );
  }

  Future<void> markRepetitionAbsence(String repetitionId, String reason) async {
    await _dio.post(
      '/repetition/$repetitionId/absence',
      data: {'reason': reason},
      options: await _authHeaders(),
    );
  }

  // ── Congés ───────────────────────────────────────────────────

  Future<void> declareLeave(
    String userId,
    String startDate,
    String endDate,
    String reason,
  ) async {
    await _dio.post(
      '/leave/$userId/declare-leave',
      data: {'startDate': startDate, 'endDate': endDate, 'reason': reason},
      options: await _authHeaders(),
    );
  }

  // ── Concerts ─────────────────────────────────────────────────

  Future<List<dynamic>> getConcerts() async {
    final response = await _dio.get('/concerts', options: await _authHeaders());
    return response.data;
  }

  Future<void> markConcertAvailability(String concertId, bool available) async {
    await _dio.patch(
      '/concerts/$concertId/availability',
      data: {'available': available},
      options: await _authHeaders(),
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getChoristeDashboard() async {
    final response = await _dio.get(
      '/dashboard/choriste',
      options: await _authHeaders(),
    );
    return response.data;
  }

  // ── Profile ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/auth/me', options: await _authHeaders());
    return response.data as Map<String, dynamic>;
  }

  // ── FCM ───────────────────────────────────────────────────────

  Future<void> saveFcmToken(String token) async {
    try {
      await _dio.patch(
        '/auth/fcm-token',
        data: {'fcmToken': token},
        options: await _authHeaders(),
      );
    } catch (e) {
      debugPrint('[FCM] Erreur save token: $e');
    }
  }

  // ── Préférences de rappel globales ────────────────────────────

  Future<Map<String, dynamic>?> getReminderPreferences() async {
    try {
      final response = await _dio.get(
        '/users/me/reminder-preferences',
        options: await _authHeaders(),
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateReminderPreferences(Map<String, dynamic> prefs) async {
    await _dio.patch(
      '/users/me/reminder-preferences',
      data: prefs,
      options: await _authHeaders(),
    );
  }

  // ── Rappels personnalisés par répétition (multi-rappels) ──────

  /// GET /choriste/repetitions/my-reminders
  ///
  /// Retourne Map<repId, List<int>>.
  /// Ex : {"64abc...": [10, 60, 1440]}
  ///
  /// ✅ Robuste : gère aussi bien l'ancien format liste que le nouveau
  /// format objet, et ne plante jamais (retourne {} en cas d'erreur).
  Future<Map<String, List<int>>> getAllMyReminders() async {
    try {
      final response = await _dio.get(
        '/choriste/repetitions/my-reminders',
        options: await _authHeaders(),
      );

      final data = response.data;

      // ── Nouveau format (objet) : { "repId": [10, 60] } ──
      if (data is Map) {
        final result = <String, List<int>>{};
        for (final entry in (data as Map<String, dynamic>).entries) {
          if (entry.value is List) {
            result[entry.key] = (entry.value as List)
                .map((e) => (e as num).toInt())
                .toList();
          }
        }
        return result;
      }

      // ── Ancien format (liste) : [{repetitionId, minutesBefore}] ──
      // Compat si le backend n'est pas encore mis à jour
      if (data is List) {
        final result = <String, List<int>>{};
        for (final item in data) {
          if (item is Map) {
            final repId = item['repetitionId']?.toString();
            final minutes = item['minutesBefore'];
            if (repId != null && minutes != null) {
              result.putIfAbsent(repId, () => []);
              result[repId]!.add((minutes as num).toInt());
            }
          }
        }
        return result;
      }

      return {};
    } on DioException catch (e) {
      debugPrint(
        '[getAllMyReminders] DioException: ${e.response?.statusCode} ${e.message}',
      );
      return {};
    } catch (e) {
      debugPrint('[getAllMyReminders] Exception: $e');
      return {};
    }
  }

  /// GET /choriste/repetitions/:repId/reminder
  ///
  /// Rappels actifs et envoyés pour une répétition précise.
  Future<Map<String, List<int>>> getMyRemindersForRep(String repId) async {
    try {
      final response = await _dio.get(
        '/choriste/repetitions/$repId/reminder',
        options: await _authHeaders(),
      );
      final data = response.data as Map<String, dynamic>;
      return {
        'minutesList': ((data['minutesList'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        'sentList': ((data['sentList'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      };
    } catch (e) {
      debugPrint('[getMyRemindersForRep] $e');
      return {'minutesList': [], 'sentList': []};
    }
  }

  /// POST /choriste/repetitions/:repId/reminder
  ///
  /// Ajoute un rappel sans toucher aux autres.
  /// Retourne false si déjà existant (409) ou erreur réseau.
  Future<bool> addRepetitionReminder(String repId, int minutesBefore) async {
    try {
      await _dio.post(
        '/choriste/repetitions/$repId/reminder',
        data: {'minutesBefore': minutesBefore},
        options: await _authHeaders(),
      );
      return true;
    } on DioException catch (e) {
      debugPrint(
        '[addRepetitionReminder] ${e.response?.statusCode} ${e.response?.data}',
      );
      return false;
    } catch (e) {
      debugPrint('[addRepetitionReminder] $e');
      return false;
    }
  }

  /// DELETE /choriste/repetitions/:repId/reminder/:minutes
  ///
  /// Supprime un rappel précis par son délai en minutes.
  Future<bool> deleteRepetitionReminder(String repId, int minutesBefore) async {
    try {
      await _dio.delete(
        '/choriste/repetitions/$repId/reminder/$minutesBefore',
        options: await _authHeaders(),
      );
      return true;
    } catch (e) {
      debugPrint('[deleteRepetitionReminder] $e');
      return false;
    }
  }

  /// DELETE /choriste/repetitions/:repId/reminders
  ///
  /// Supprime TOUS les rappels non-envoyés de cette répétition.
  Future<bool> deleteAllRepetitionReminders(String repId) async {
    try {
      await _dio.delete(
        '/choriste/repetitions/$repId/reminders',
        options: await _authHeaders(),
      );
      return true;
    } catch (e) {
      debugPrint('[deleteAllRepetitionReminders] $e');
      return false;
    }
  }

  /// PATCH /choriste/repetitions/:repId/reminder  (compat legacy)
  ///
  /// Remplace TOUS les rappels par un seul, ou supprime tout si null.
  Future<bool> setRepetitionReminder(String repId, int? minutesBefore) async {
    try {
      await _dio.patch(
        '/choriste/repetitions/$repId/reminder',
        data: {'minutesBefore': minutesBefore},
        options: await _authHeaders(),
      );
      return true;
    } catch (e) {
      debugPrint('[setRepetitionReminder] $e');
      return false;
    }
  }
}
