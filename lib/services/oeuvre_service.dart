import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/oeuvre_model.dart';

class OeuvreService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authHeaders() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ─── Construire l'URL complète d'un fichier ───────────────────────────────
  // Ex: buildFileUrl('documents/123-partition.pdf')
  //  →  http://192.168.x.x:3000/uploads/documents/123-partition.pdf
  static String buildFileUrl(String filename) {
    if (filename.isEmpty) return '';
    // Si déjà une URL complète
    if (filename.startsWith('http')) return filename;
    // Déterminer le sous-dossier selon l'extension
    final ext = filename.split('.').last.toLowerCase();
    String subfolder;
    if (ext == 'pdf') {
      subfolder = 'documents';
    } else if (['mp4', 'mov', 'avi'].contains(ext)) {
      subfolder = 'videos';
    } else {
      subfolder = 'audios';
    }
    return '${ApiConfig.baseUrl}/uploads/$subfolder/$filename';
  }

  // ─── GET /oeuvres ─────────────────────────────────────────────────────────
  Future<List<OeuvreModel>> getOeuvres() async {
    final response = await _dio.get('/oeuvres', options: await _authHeaders());
    return (response.data as List)
        .map((e) => OeuvreModel.fromJson(e))
        .toList();
  }

  // ─── GET /oeuvres/:id ─────────────────────────────────────────────────────
  Future<OeuvreModel> getOeuvreById(String id) async {
    final response =
        await _dio.get('/oeuvres/$id', options: await _authHeaders());
    return OeuvreModel.fromJson(response.data);
  }

  // ─── POST /oeuvres ────────────────────────────────────────────────────────
  Future<OeuvreModel> createOeuvre({
    required Map<String, dynamic> data,
    File? lyricsFile,
    File? partitionFile,
    File? videoFile,
    File? audioFile,
  }) async {
    final formData = FormData.fromMap({
      ...data,
      if (lyricsFile != null)
        'lyrics': await MultipartFile.fromFile(lyricsFile.path,
            filename: lyricsFile.path.split('/').last),
      if (partitionFile != null)
        'partition': await MultipartFile.fromFile(partitionFile.path,
            filename: partitionFile.path.split('/').last),
      if (videoFile != null)
        'video': await MultipartFile.fromFile(videoFile.path,
            filename: videoFile.path.split('/').last),
      if (audioFile != null)
        'audio': await MultipartFile.fromFile(audioFile.path,
            filename: audioFile.path.split('/').last),
    });

    final response = await _dio.post(
      '/oeuvres',
      data: formData,
      options: await _authHeaders(),
    );
    return OeuvreModel.fromJson(response.data['oeuvre']);
  }

  // ─── PATCH /oeuvres/:id ───────────────────────────────────────────────────
  Future<OeuvreModel> updateOeuvre({
    required String id,
    required Map<String, dynamic> data,
    File? lyricsFile,
    File? partitionFile,
    File? videoFile,
    File? audioFile,
  }) async {
    final formData = FormData.fromMap({
      ...data,
      if (lyricsFile != null)
        'lyrics': await MultipartFile.fromFile(lyricsFile.path,
            filename: lyricsFile.path.split('/').last),
      if (partitionFile != null)
        'partition': await MultipartFile.fromFile(partitionFile.path,
            filename: partitionFile.path.split('/').last),
      if (videoFile != null)
        'video': await MultipartFile.fromFile(videoFile.path,
            filename: videoFile.path.split('/').last),
      if (audioFile != null)
        'audio': await MultipartFile.fromFile(audioFile.path,
            filename: audioFile.path.split('/').last),
    });

    final response = await _dio.patch(
      '/oeuvres/$id',
      data: formData,
      options: await _authHeaders(),
    );
    return OeuvreModel.fromJson(response.data['updated']);
  }

  // ─── PATCH /oeuvres/:id/visibility ───────────────────────────────────────
  Future<bool> toggleVisibility(String id) async {
    final response = await _dio.patch(
      '/oeuvres/$id/visibility',
      options: await _authHeaders(),
    );
    return response.data['isVisible'] as bool;
  }

  // ─── DELETE /oeuvres/:id/permanent ───────────────────────────────────────
  Future<void> deleteOeuvre(String id) async {
    await _dio.delete('/oeuvres/$id/permanent',
        options: await _authHeaders());
  }
}