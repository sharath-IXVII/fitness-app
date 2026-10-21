import 'package:flutter/material.dart';

/// Brand palette. Dark-first, with a lime → mint signature gradient.
abstract final class AppColors {
  static const background = Color(0xFF07090D);
  static const surface = Color(0xFF10141B);
  static const surfaceHigh = Color(0xFF171C26);
  static const stroke = Color(0x1AFFFFFF);

  static const textPrimary = Color(0xFFF4F6FA);
  static const textSecondary = Color(0xFF9AA3B2);
  static const textMuted = Color(0xFF5E6675);

  static const lime = Color(0xFFC6F432);
  static const mint = Color(0xFF2EE6A8);

  // One accent per pillar so the user learns the colour language.
  static const workout = lime;
  static const water = Color(0xFF4FC3F7);
  static const steps = Color(0xFFFF8A3D);
  static const diet = Color(0xFFA78BFA);
  static const protein = Color(0xFFFF5C8A);

  static const danger = Color(0xFFFF4D5E);

  static const brandGradient = LinearGradient(
    colors: [lime, mint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Heatmap intensity levels, from "no activity" to "perfect day".
  static const heat = [Color(0xFF1A1F29), Color(0xFF1F4A2E), Color(0xFF2B7A3F), Color(0xFF55B84A), Color(0xFFC6F432)];
}
