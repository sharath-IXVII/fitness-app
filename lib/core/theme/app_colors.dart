import 'package:flutter/material.dart';

/// Brand palette. Warm cream canvas, white cards and a deep emerald accent.
abstract final class AppColors {
  // "Golden hour" — built on the Light & Airy palette:
  // Salmon F28775 · Peach F7C289 · Candy corn EAE48F · Pale F9D9C0 · Linen F9F6E4.
  static const linen = Color(0xFFF9F6E4);
  static const pale = Color(0xFFF9D9C0);
  static const peach = Color(0xFFF7C289);
  static const salmon = Color(0xFFF28775);
  static const candyCorn = Color(0xFFEAE48F);

  static const background = Color(0xFFFAF6EA);
  static const surface = Color(0xFFFFFDF7);
  static const surfaceHigh = Color(0xFFF7EADB);
  static const stroke = Color(0xFFF0E2CE);
  static const shadow = Color(0xFF8A4A36);

  static const textPrimary = Color(0xFF2E2420);
  static const textSecondary = Color(0xFF7D6A60);
  static const textMuted = Color(0xFFB5A69A);

  /// Salmon deepened just enough for white text to stay readable on it.
  static const primary = Color(0xFFDE6450);
  static const accent = salmon;
  static const gold = peach;
  static const sunrise = peach;

  /// Peach is too light for text; use this amber when it has to be read.
  static const amber = Color(0xFFB9772A);

  // One accent per pillar so the user learns the colour language.
  static const workout = primary;
  static const water = Color(0xFF5C9EC7);
  static const steps = Color(0xFF8FA650);
  static const diet = Color(0xFFA88BC9);
  static const protein = Color(0xFFE26D8A);

  static const danger = Color(0xFFC9433A);

  /// Sunset sweep used on primary buttons and the logo.
  static const brandGradient = LinearGradient(
    colors: [Color(0xFFE0604B), Color(0xFFF28775), Color(0xFFF5A77A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Heatmap levels: linen → pale → peach → salmon → deep coral.
  static const heat = [Color(0xFFF1EADA), pale, peach, salmon, Color(0xFFD9584A)];

  static List<BoxShadow> softShadow([Color tint = shadow]) => [
    BoxShadow(color: tint.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 12), spreadRadius: -8),
    BoxShadow(color: tint.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
  ];
}
