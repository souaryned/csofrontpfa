import 'dart:io';
import 'package:cso_mobile/services/notification_service.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitializing = true; // true pendant loadUser() au démarrage
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  // ─────────────────────────────────────────────────────────────
  // CHARGEMENT AU DÉMARRAGE
  //
  // Appelé dans main() avant runApp().
  // AuthService.getMe() lit le token JWT depuis flutter_secure_storage
  // et appelle GET /auth/me pour le valider.
  //   → valide   : _user rempli, SplashScreen → HomeScreen
  //   → expiré   : getMe() supprime le token, retourne null → LoginScreen
  //   → pas réseau : getMe() retourne null → LoginScreen
  //     (amélioration possible : cache local hors-ligne)
  // ─────────────────────────────────────────────────────────────

  Future<void> loadUser() async {
    try {
      _user = await _authService.getMe();

      // Si connecté → rafraîchir le token FCM silencieusement
      // sans bloquer : garantit que le backend a toujours le bon token
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
    // Supprimer le token FCM du backend → plus de notifications après logout
    try {
      await NotificationService.deleteTokenOnLogout();
    } catch (_) {}

    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
