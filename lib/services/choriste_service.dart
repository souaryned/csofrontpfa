import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ChoristeService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authHeaders() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

// Répétitions
Future<List<dynamic>> getRepetitions() async {
  final response = await _dio.get('/repetition', options: await _authHeaders());
  return response.data;
}

Future<void> markRepetitionPresence(String repetitionId) async {
  await _dio.post('/repetition/$repetitionId/presence', options: await _authHeaders());
}

Future<void> markRepetitionAbsence(String repetitionId, String reason) async {
  await _dio.post(
    '/repetition/$repetitionId/absence',
    data: {'reason': reason},
    options: await _authHeaders(),
  );
}

// Congés
Future<void> declareLeave(String userId, String startDate, String endDate, String reason) async {
  await _dio.post(
    '/leave/$userId/declare-leave',
    data: {
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
    },
    options: await _authHeaders(),
  );
}

  // ── Concerts ──
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
  Future<Map<String, dynamic>> getChoristeDashboard() async {
  final response = await _dio.get(
    '/dashboard/choriste',
    options: await _authHeaders(),
  );
  return response.data;
}


}