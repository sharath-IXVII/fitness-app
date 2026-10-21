import 'package:flutter/material.dart';

/// Brand palette: light cream, light brown and white only. Every accent is
/// a shade of brown so the app stays calm and consistent; text uses a deep
/// brown rather than black for readability.
abstract final class AppColors {
  static const background = Color(0xFFFAF6EF); // light cream
  static const surface = Color(0xFFFFFFFF); // white
  static const surfaceHigh = Color(0xFFF3ECE2); // deeper cream
  static const stroke = Color(0xFFEAE0D3);
  static const shadow = Color(0xFF5C4430);

  static const textPrimary = Color(0xFF3A2E25);
  // Text greys are tuned for legibility on cream: secondary ≈ 5.9:1,
  // tertiary ≈ 4.8:1 (small print), muted only for icons and placeholders.
  static const textSecondary = Color(0xFF6E5C4B);
  static const textTertiary = Color(0xFF7D6A58);
  static const textMuted = Color(0xFFAE9D8B);

  static const primary = Color(0xFFA47551); // light brown
  static const primarySoft = Color(0xFFF2E7DA);
  static const accent = Color(0xFFC49A74);
  static const gold = Color(0xFFC9A27E);
  static const amber = Color(0xFF8C6340);

  // Pillars are told apart by shade and icon, all within the brown family.
  static const workout = primary;
  static const water = Color(0xFFB98D68);
  static const steps = Color(0xFF8C6A4F);
  static const diet = Color(0xFFC9A27E);
  static const protein = Color(0xFF7A5A43);

  static const danger = Color(0xFFA6523F);

  /// Barely-there gradient for primary buttons; reads as a solid colour.
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF9E6F4B), Color(0xFFAA7C58)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Heatmap levels: cream → light brown → brown.
  static const heat = [Color(0xFFF0E8DC), Color(0xFFE6D3BD), Color(0xFFD2B190), Color(0xFFB98D68), Color(0xFF8C6340)];

  static List<BoxShadow> softShadow([Color tint = shadow]) => [
    BoxShadow(color: tint.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4), spreadRadius: -2),
    BoxShadow(color: tint.withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1)),
  ];
}
