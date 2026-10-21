import 'package:flutter/material.dart';

/// Brand palette: a very light, neutral canvas with a single calm indigo
/// accent. Colour is used sparingly — for progress and actions only.
abstract final class AppColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFF1F3F6);
  static const stroke = Color(0xFFE7E9EE);
  static const shadow = Color(0xFF101828);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  static const primary = Color(0xFF4F46E5);
  static const primarySoft = Color(0xFFEEF0FF);
  static const accent = Color(0xFF6366F1);
  static const gold = Color(0xFFF59E0B);
  static const amber = Color(0xFFB45309);

  // One accent per pillar so the user learns the colour language.
  static const workout = primary;
  static const water = Color(0xFF0EA5E9);
  static const steps = Color(0xFF10B981);
  static const diet = Color(0xFFF59E0B);
  static const protein = Color(0xFFEC4899);

  static const danger = Color(0xFFDC2626);

  /// Barely-there gradient for primary buttons; reads as a solid colour.
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF5B54EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Heatmap levels: empty grey → light indigo → full indigo.
  static const heat = [Color(0xFFEDEFF3), Color(0xFFDDE1FF), Color(0xFFB4BBFB), Color(0xFF7C80F0), primary];

  static List<BoxShadow> softShadow([Color tint = shadow]) => [
    BoxShadow(color: tint.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4), spreadRadius: -2),
    BoxShadow(color: tint.withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1)),
  ];
}
