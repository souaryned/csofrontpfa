import 'dart:io';
import 'package:cso_mobile/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  // ─────────────────────────────────────────────────────────────
  // CHARGEMENT AU DÉMARRAGE
  // ─────────────────────────────────────────────────────────────

  Future<void> loadUser() async {
    try {
      _user = await _authService.getMe();

      // Si connecté → rafraîchir le token FCM silencieusement
      if (_user != null) {
        NotificationService.saveTokenAfterLogin();
      }
    } catch (e) {
      debugPrint('[AuthProvider] loadUser error: $e');
      _user = null;
    }

    _isInitializing = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      _isLoading = false;
      notifyListeners();

      // Envoyer le token FCM au backend après login
      await NotificationService.refreshAndSaveToken();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE PROFIL
  // ─────────────────────────────────────────────────────────────

  Future<bool> updateProfile(
    Map<String, dynamic> data, {
    File? avatarFile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.updateMe(data, avatarFile: avatarFile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Ordre correct :
    // 1. Dissocier le token FCM du backend (pendant que le JWT est encore valide)
    // 2. Supprimer le JWT local
    // 3. Vider l'état
    try {
      await NotificationService.deleteTokenOnLogout();
    } catch (_) {}

    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
