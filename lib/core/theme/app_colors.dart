import 'package:flutter/material.dart';

/// Brand palette. Warm cream canvas, white cards and a deep emerald accent.
abstract final class AppColors {
  static const background = Color(0xFFF6F3EC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFEFEAE0);
  static const stroke = Color(0xFFE7E1D5);
  static const shadow = Color(0xFF3C2D19);

  static const textPrimary = Color(0xFF1F1D1A);
  static const textSecondary = Color(0xFF6F685E);
  static const textMuted = Color(0xFFA8A095);

  static const primary = Color(0xFF1F6B4F);
  static const accent = Color(0xFF3E9C77);
  static const gold = Color(0xFFE9A93B);

  // One accent per pillar so the user learns the colour language.
  static const workout = primary;
  static const water = Color(0xFF2F7FC1);
  static const steps = Color(0xFFD9733B);
  static const diet = Color(0xFF7C5CC4);
  static const protein = Color(0xFFCC4F74);

  static const danger = Color(0xFFD64545);

  static const brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Heatmap intensity levels, from "no activity" to "perfect day".
  static const heat = [Color(0xFFECE6DA), Color(0xFFCFE5D6), Color(0xFF94C9A9), Color(0xFF4E9E77), Color(0xFF1F6B4F)];

  static List<BoxShadow> softShadow([Color tint = shadow]) => [
    BoxShadow(color: tint.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -4),
    BoxShadow(color: tint.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
  ];
}
