import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['token'];
      await _storage.write(key: 'token', value: token);

      // ✅ Après login, appeler getMe pour avoir TOUTES les données (avatar inclus)
      // car la réponse du login ne contient pas forcément tous les champs
      final user = await getMe();
      if (user != null) return user;

      // Fallback si getMe échoue
      return UserModel.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Erreur de connexion';
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final token = await _storage.read(key: 'token');
      
      print('[getMe] token: ${token != null ? "présent" : "NULL"}');
      
      if (token == null) return null;

      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print('[getMe] status: ${response.statusCode}');
      print('[getMe] avatar: ${response.data['avatar']}');
      print('[getMe] data complète: ${response.data}');

      return UserModel.fromJson(response.data);

    } on DioException catch (e) {
      print('[getMe] DioException: ${e.response?.statusCode} — ${e.message}');
      // Token expiré → on le supprime
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _storage.delete(key: 'token');
        print('[getMe] Token supprimé car invalide');
      }
      return null;
    } catch (e) {
      print('[getMe] Erreur inattendue: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
  }

  Future<UserModel> updateMe(Map<String, dynamic> data, {File? avatarFile}) async {
    final token = await _storage.read(key: 'token');
    Response response;

    if (avatarFile != null) {
      final formData = FormData.fromMap({
        ...data,
        'avatar': await MultipartFile.fromFile(
          avatarFile.path,
          filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });
      response = await _dio.patch(
        '/auth/me',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } else {
      response = await _dio.patch(
        '/auth/me',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    }

    print('[updateMe] avatar retourné: ${response.data['user']?['avatar']}');
    final updatedUserJson = response.data['user'] ?? response.data;
    return UserModel.fromJson(updatedUserJson);
  }
}