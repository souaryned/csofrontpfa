import 'package:flutter/material.dart';

/// Palette partagée — alignée sur le dashboard.
abstract final class AppColors {
  static const background = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1D26);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE8ECF4);
  static const accent = Color(0xFF4F5D94);

  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFFF7ED);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEF2F2);

  static const repAccent = Color(0xFFD97706);
  static const concertAccent = Color(0xFFBE185D);
  static const messageAccent = Color(0xFF7C3AED);
  static const surveyAccent = Color(0xFF0D9488);

  static Color pupitre(String p) {
    switch (p) {
      case 'soprano':
        return const Color(0xFF7C3AED);
      case 'alto':
        return const Color(0xFF0891B2);
      case 'ténor':
        return const Color(0xFF059669);
      case 'basse':
        return const Color(0xFFB45309);
      default:
        return accent;
    }
  }

  static String pupitreLabel(String p) {
    switch (p) {
      case 'soprano':
        return 'Soprano';
      case 'alto':
        return 'Alto';
      case 'ténor':
        return 'Ténor';
      case 'basse':
        return 'Basse';
      default:
        return p.isEmpty ? '' : p;
    }
  }
}
