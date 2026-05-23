// services/survey_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class SurveyService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authHeaders() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // GET /surveys — liste des sondages actifs pour le choriste
  Future<List<dynamic>> getSurveys() async {
    final response = await _dio.get(
      '/surveys',
      options: await _authHeaders(),
    );
    return response.data as List<dynamic>;
  }

  // GET /surveys/:id — détail d'un sondage
  Future<Map<String, dynamic>> getSurveyById(String id) async {
    final response = await _dio.get(
      '/surveys/$id',
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  // GET /surveys/:id/ma-reponse — vérifier si le choriste a déjà répondu
  Future<Map<String, dynamic>?> getMaReponse(String surveyId) async {
    try {
      final response = await _dio.get(
        '/surveys/$surveyId/ma-reponse',
        options: await _authHeaders(),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // POST /surveys/:id/reponses — soumettre les réponses
  Future<void> soumettreReponses({
    required String surveyId,
    required List<Map<String, dynamic>> reponses,
  }) async {
    await _dio.post(
      '/surveys/$surveyId/reponses',
      data: {'reponses': reponses},
      options: await _authHeaders(),
    );
  }
}