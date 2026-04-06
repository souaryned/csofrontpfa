import 'dart:io';
import 'package:flutter/material.dart';
import '../models/oeuvre_model.dart';
import '../services/oeuvre_service.dart';

class OeuvreProvider extends ChangeNotifier {
  final OeuvreService _service = OeuvreService();

  List<OeuvreModel> _oeuvres = [];
  bool _isLoading = false;
  String? _error;

  List<OeuvreModel> get oeuvres => _oeuvres;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ─── Charger toutes les œuvres ────────────────────────────────────────────
  Future<void> loadOeuvres() async {
    _setLoading(true);
    _error = null;
    try {
      _oeuvres = await _service.getOeuvres();
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ─── Créer ────────────────────────────────────────────────────────────────
  Future<bool> createOeuvre({
    required Map<String, dynamic> data,
    File? lyricsFile,
    File? partitionFile,
    File? videoFile,
    File? audioFile,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final created = await _service.createOeuvre(
        data: data,
        lyricsFile: lyricsFile,
        partitionFile: partitionFile,
        videoFile: videoFile,
        audioFile: audioFile,
      );
      _oeuvres.insert(0, created);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _parseError(e);
      _setLoading(false);
      return false;
    }
  }

  // ─── Modifier ─────────────────────────────────────────────────────────────
  Future<bool> updateOeuvre({
    required String id,
    required Map<String, dynamic> data,
    File? lyricsFile,
    File? partitionFile,
    File? videoFile,
    File? audioFile,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _service.updateOeuvre(
        id: id,
        data: data,
        lyricsFile: lyricsFile,
        partitionFile: partitionFile,
        videoFile: videoFile,
        audioFile: audioFile,
      );
      final idx = _oeuvres.indexWhere((o) => o.id == id);
      if (idx != -1) _oeuvres[idx] = updated;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _parseError(e);
      _setLoading(false);
      return false;
    }
  }

  // ─── Basculer visibilité ──────────────────────────────────────────────────
  Future<void> toggleVisibility(String id) async {
    try {
      final newVal = await _service.toggleVisibility(id);
      final idx = _oeuvres.indexWhere((o) => o.id == id);
      if (idx != -1) {
        _oeuvres[idx] = _oeuvres[idx].copyWith(isVisible: newVal);
        notifyListeners();
      }
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
    }
  }

  // ─── Supprimer ────────────────────────────────────────────────────────────
  Future<bool> deleteOeuvre(String id) async {
    try {
      await _service.deleteOeuvre(id);
      _oeuvres.removeWhere((o) => o.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  String _parseError(dynamic e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return e.toString();
  }
}