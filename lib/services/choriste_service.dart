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

  // ── Répétitions ──

  Future<List<dynamic>> getRepetitions() async {
    final response =
        await _dio.get('/repetition', options: await _authHeaders());
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

  Future<void> markRepetitionAbsence(
      String repetitionId, String reason) async {
    await _dio.post(
      '/repetition/$repetitionId/absence',
      data: {'reason': reason},
      options: await _authHeaders(),
    );
  }

  // ── Congés ──

  Future<void> declareLeave(
      String userId, String startDate, String endDate, String reason) async {
    await _dio.post(
      '/leave/$userId/declare-leave',
      data: {'startDate': startDate, 'endDate': endDate, 'reason': reason},
      options: await _authHeaders(),
    );
  }

  // ── Concerts ──

  Future<List<dynamic>> getConcerts() async {
    final response =
        await _dio.get('/concerts', options: await _authHeaders());
    return response.data;
  }

  Future<void> markConcertAvailability(String concertId, bool available) async {
    await _dio.patch(
      '/concerts/$concertId/availability',
      data: {'available': available},
      options: await _authHeaders(),
    );
  }

  // ── Dashboard ──

  Future<Map<String, dynamic>> getChoristeDashboard() async {
    final response = await _dio.get(
      '/dashboard/choriste',
      options: await _authHeaders(),
    );
    return response.data;
  }

  // ── Profile ──

  /// Returns the full user profile from the backend (includes pupitre,
  /// isChefDePupitre, etc.).
  Future<Map<String, dynamic>> getMyProfile() async {
    final response =
        await _dio.get('/auth/me', options: await _authHeaders());
    return response.data as Map<String, dynamic>;
  }

  // ── FCM ──

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
}