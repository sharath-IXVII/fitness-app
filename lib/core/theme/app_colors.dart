import 'package:flutter/material.dart';

/// Brand palette. Warm cream canvas, white cards and a deep emerald accent.
abstract final class AppColors {
  // "Morning latte": warm cream paper, espresso ink, caramel accents.
  static const background = Color(0xFFF7F1E8);
  static const surface = Color(0xFFFFFCF7);
  static const surfaceHigh = Color(0xFFF0E6D8);
  static const stroke = Color(0xFFE8DCCB);
  static const shadow = Color(0xFF5A3A1E);

  static const textPrimary = Color(0xFF2B2118);
  static const textSecondary = Color(0xFF7A6A58);
  static const textMuted = Color(0xFFB0A08C);

  static const primary = Color(0xFF8B5A35);
  static const accent = Color(0xFFC9834B);
  static const gold = Color(0xFFE2A94F);
  static const sunrise = Color(0xFFF0B27A);

  // One accent per pillar so the user learns the colour language.
  static const workout = primary;
  static const water = Color(0xFF4F8DB5);
  static const steps = Color(0xFF6E9B6A);
  static const diet = Color(0xFF9478B4);
  static const protein = Color(0xFFC8606E);

  static const danger = Color(0xFFC94A3F);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF7E4E2C), Color(0xFFC9834B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Heatmap intensity levels, from "no activity" (cream) to "perfect day" (espresso).
  static const heat = [Color(0xFFEFE5D7), Color(0xFFF2D7B5), Color(0xFFE3B47E), Color(0xFFC4844C), Color(0xFF7E4E2C)];

  static List<BoxShadow> softShadow([Color tint = shadow]) => [
    BoxShadow(color: tint.withValues(alpha: 0.08), blurRadius: 28, offset: const Offset(0, 10), spreadRadius: -6),
    BoxShadow(color: tint.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
  ];
}
