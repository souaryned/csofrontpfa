// services/chef_pupitre_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ChefPupitreService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authHeaders() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Présences ──

  /// Retourne la répétition en cours + liste des choristes avec leur statut.
  Future<Map<String, dynamic>> getActiveRepetitionPresences() async {
    final response = await _dio.get(
      '/chef-pupitre/repetition-active/presences',
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Modifier le statut d'un choriste (present | absent)
  Future<void> updateChoristPresence({
    required String repetitionId,
    required String userId,
    required String status, // 'present' | 'absent'
    String? reason,
  }) async {
    await _dio.patch(
      '/chef-pupitre/repetition/$repetitionId/choriste/$userId/presence',
      data: {'status': status, if (reason != null) 'reason': reason},
      options: await _authHeaders(),
    );
  }

  /// Valider et envoyer la liste des présences au chef de chœur
  Future<void> validateAndSendPresenceList(String repetitionId) async {
    await _dio.post(
      '/chef-pupitre/repetition/$repetitionId/validate-presences',
      options: await _authHeaders(),
    );
  }

  // ── Messagerie ──

  /// Envoyer un message à un ou plusieurs choristes du pupitre
  Future<void> sendMessage({
    required List<String> recipientIds,
    required String content,
    String? repetitionId,
  }) async {
    await _dio.post(
      '/chef-pupitre/message',
      data: {
        'recipientIds': recipientIds,
        'content': content,
        if (repetitionId != null) 'repetitionId': repetitionId,
      },
      options: await _authHeaders(),
    );
  }

  /// Historique des messages du chef
  Future<List<dynamic>> getChefMessages() async {
    final response = await _dio.get(
      '/chef-pupitre/messages',
      options: await _authHeaders(),
    );
    return response.data['messages'] as List<dynamic>;
  }

  /// Messages reçus par le choriste (appel côté choriste)
  Future<List<dynamic>> getChoristMessages() async {
    final response = await _dio.get(
      '/choriste/messages',
      options: await _authHeaders(),
    );
    return response.data['messages'] as List<dynamic>;
  }
  Future<List<dynamic>> getChoristesForPupitre() async {
    final response = await _dio.get(
      '/chef-pupitre/choristes',
      options: await _authHeaders(), // ✅ token ajouté
    );
    return (response.data['choristes'] as List? ?? []);
  }
}