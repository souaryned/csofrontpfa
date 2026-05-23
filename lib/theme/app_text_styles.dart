import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Styles de texte sans décoration (évite les soulignements jaunes M3).
abstract final class AppTextStyles {
  static const _base = TextStyle(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    decoration: TextDecoration.none,
  );

  static const subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static const body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.35,
    decoration: TextDecoration.none,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    decoration: TextDecoration.none,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  static TextStyle accent(Color color) => _base.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      );
}
