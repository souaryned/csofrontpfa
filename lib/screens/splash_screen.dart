import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // ✅ écran principal de l'app

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _textFadeAnim;

  // Durée minimale d'affichage du splash (pour laisser l'animation se jouer)
  static const _minSplashDuration = Duration(milliseconds: 1800);

  bool _animationDone = false;
  bool _authDone = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    // ── Animations ────────────────────────────────────────────
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _textFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1, curve: Curves.easeOut),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });

    // ── Durée minimale avant navigation ──────────────────────
    Future.delayed(_minSplashDuration, () {
      _animationDone = true;
      _tryNavigate();
    });

    // ── Lire AuthProvider après le premier frame ──────────────
    // loadUser() est déjà appelé dans main() avant runApp(),
    // donc isInitializing peut déjà être false ici.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isInitializing) {
        _authDone = true;
        _tryNavigate();
      } else {
        auth.addListener(_onAuthChanged);
      }
    });
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (!auth.isInitializing) {
      auth.removeListener(_onAuthChanged);
      _authDone = true;
      _tryNavigate();
    }
  }

  // Naviguer seulement quand les DEUX conditions sont remplies :
  // 1. Durée minimale du splash écoulée
  // 2. AuthProvider a fini loadUser()
  void _tryNavigate() {
    if (!_animationDone || !_authDone) return;
    if (!mounted) return;

    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isLoggedIn ? const HomeScreen() : const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    try {
      context.read<AuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          // Cercle teal haut droite
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                color: Color(0xFF2DD4BF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Cercle violet bas gauche
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                color: Color(0xFF9B8EC4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Petit cercle bleu
          Positioned(
            top: 220,
            right: 30,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Petit cercle teal
          Positioned(
            bottom: 200,
            left: 30,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF2DD4BF),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Carte centrale ─────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 32,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/logo.png',
                        height: 100,
                        width: 100,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Color(0xFF2DD4BF),
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ligne décorative
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.music_note,
                            color: Color(0xFF2DD4BF),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Titre
                      FadeTransition(
                        opacity: _textFadeAnim,
                        child: const Text(
                          'CSO',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _textFadeAnim,
                        child: const Text(
                          'Carthage Symphony Orchestra',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2DD4BF),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Spinner de chargement
                      FadeTransition(
                        opacity: _textFadeAnim,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF2DD4BF),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
