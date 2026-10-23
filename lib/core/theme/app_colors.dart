import 'package:flutter/material.dart';

import 'palette.dart';

/// The app's colours, read from the current seasonal [Palette]. The season
/// (see SeasonArc) picks the palette by date, so the look changes by itself
/// every three months.
abstract final class AppColors {
  static Palette _p = Palette.winter;

  static Palette get palette => _p;

  /// Switches every colour. Rebuild the widget tree afterwards.
  static void use(Palette p) => _p = p;

  static Color get background => _p.background;
  static const surface = Color(0xFFFFFFFF);
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get stroke => _p.stroke;
  static Color get shadow => _p.shadow;

  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textTertiary => _p.textTertiary;
  static Color get textMuted => _p.textMuted;

  static Color get primary => _p.primary;
  static Color get primarySoft => _p.primarySoft;
  static Color get accent => _p.accent;
  static Color get gold => _p.gold;
  static Color get amber => _p.amber;

  // Hero cards and the energy gradient on rings and bars.
  static Color get ink => _p.ink;
  static Color get inkSoft => _p.inkSoft;
  static Color get energy => _p.energy;
  static Color get energyLight => _p.energyLight;
  static LinearGradient get energyGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [energyLight, energy, primary]);

  // Pillars are told apart by shade and icon.
  static Color get workout => primary;
  static Color get water => _p.water;
  static Color get steps => _p.steps;
  static Color get diet => _p.diet;
  static Color get protein => _p.protein;

  static const danger = Color(0xFFA6523F);

  /// Barely-there gradient for primary buttons; reads as a solid colour.
  static LinearGradient get brandGradient => LinearGradient(
    colors: [_p.primaryDeep, Color.lerp(_p.primaryDeep, _p.primary, 0.9)!],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Calendar levels: empty → full.
  static List<Color> get heat => _p.heat;

  static List<BoxShadow> softShadow([Color? tint]) => [
    BoxShadow(
      color: (tint ?? shadow).withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(color: (tint ?? shadow).withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1)),
  ];
}
