import 'package:flutter/material.dart';

/// Every colour the app uses. Each seasonal arc has its own palette; see
/// AppColors for how the current one is read.
class Palette {
  const Palette({
    required this.background,
    required this.surfaceHigh,
    required this.stroke,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.accent,
    required this.gold,
    required this.amber,
    required this.ink,
    required this.inkSoft,
    required this.energy,
    required this.energyLight,
    required this.water,
    required this.steps,
    required this.diet,
    required this.protein,
    required this.heat,
  });

  final Color background;
  final Color surfaceHigh;
  final Color stroke;
  final Color shadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color primary;

  /// Darker end of the button gradient.
  final Color primaryDeep;
  final Color primarySoft;
  final Color accent;
  final Color gold;
  final Color amber;
  final Color ink;
  final Color inkSoft;
  final Color energy;
  final Color energyLight;
  final Color water;
  final Color steps;
  final Color diet;
  final Color protein;

  /// Five calendar levels, empty → full.
  final List<Color> heat;

  /// The original light cream and brown look.
  static const classic = Palette(
    background: Color(0xFFFAF6EF),
    surfaceHigh: Color(0xFFF3ECE2),
    stroke: Color(0xFFEAE0D3),
    shadow: Color(0xFF5C4430),
    textPrimary: Color(0xFF3A2E25),
    textSecondary: Color(0xFF6E5C4B),
    textTertiary: Color(0xFF7D6A58),
    textMuted: Color(0xFFAE9D8B),
    primary: Color(0xFFA47551),
    primaryDeep: Color(0xFF9E6F4B),
    primarySoft: Color(0xFFF2E7DA),
    accent: Color(0xFFC49A74),
    gold: Color(0xFFC9A27E),
    amber: Color(0xFF8C6340),
    ink: Color(0xFF2B1F17),
    inkSoft: Color(0xFF3D2E23),
    energy: Color(0xFFD08A4E),
    energyLight: Color(0xFFE9B37E),
    water: Color(0xFFB98D68),
    steps: Color(0xFF8C6A4F),
    diet: Color(0xFFC9A27E),
    protein: Color(0xFF7A5A43),
    heat: [Color(0xFFF0E8DC), Color(0xFFE6D3BD), Color(0xFFD2B190), Color(0xFFB98D68), Color(0xFF8C6340)],
  );

  /// Winter Arc: snow white, ice blue and a deep night sky.
  static const winter = Palette(
    background: Color(0xFFF2F6FA),
    surfaceHigh: Color(0xFFE5EDF5),
    stroke: Color(0xFFD7E2EC),
    shadow: Color(0xFF26415C),
    textPrimary: Color(0xFF1C2A39),
    textSecondary: Color(0xFF4A5D72),
    textTertiary: Color(0xFF586B80),
    textMuted: Color(0xFF97A8BA),
    primary: Color(0xFF3B78B2),
    primaryDeep: Color(0xFF2F679E),
    primarySoft: Color(0xFFE0ECF7),
    accent: Color(0xFF7DAFDC),
    gold: Color(0xFF9DB7CF),
    amber: Color(0xFF2B5885),
    ink: Color(0xFF11223A),
    inkSoft: Color(0xFF1E3654),
    energy: Color(0xFF5FB2E6),
    energyLight: Color(0xFFBCE3F8),
    water: Color(0xFF4F9AD0),
    steps: Color(0xFF5674A0),
    diet: Color(0xFF7FA8C9),
    protein: Color(0xFF34597F),
    heat: [Color(0xFFE6EEF6), Color(0xFFC8DBEE), Color(0xFF98BEE2), Color(0xFF639ACF), Color(0xFF2F6AA4)],
  );

  /// Rise of Revolution: revolution red and saffron on warm white.
  static const revolution = Palette(
    background: Color(0xFFFBF4F1),
    surfaceHigh: Color(0xFFF5E8E3),
    stroke: Color(0xFFEDDAD3),
    shadow: Color(0xFF5A2219),
    textPrimary: Color(0xFF34191A),
    textSecondary: Color(0xFF6D4B47),
    textTertiary: Color(0xFF7A5853),
    textMuted: Color(0xFFB39A95),
    primary: Color(0xFFB23A2B),
    primaryDeep: Color(0xFF9E2F22),
    primarySoft: Color(0xFFF7E1DC),
    accent: Color(0xFFD9744F),
    gold: Color(0xFFD9A441),
    amber: Color(0xFF8A2A1F),
    ink: Color(0xFF2A1110),
    inkSoft: Color(0xFF431B17),
    energy: Color(0xFFE8892F),
    energyLight: Color(0xFFF6C26B),
    water: Color(0xFFCC6A4E),
    steps: Color(0xFF9B4A3A),
    diet: Color(0xFFD9A441),
    protein: Color(0xFF7E2E24),
    heat: [Color(0xFFF4E6E1), Color(0xFFF0C9BC), Color(0xFFE5987F), Color(0xFFCF5F45), Color(0xFFA2301F)],
  );

  /// Summer Arc: sunshine orange and golden yellow.
  static const summer = Palette(
    background: Color(0xFFFFF8EE),
    surfaceHigh: Color(0xFFFBEEDB),
    stroke: Color(0xFFF2E1C8),
    shadow: Color(0xFF6A4114),
    textPrimary: Color(0xFF3A2610),
    textSecondary: Color(0xFF6F5233),
    textTertiary: Color(0xFF7C5F3E),
    textMuted: Color(0xFFB9A07F),
    primary: Color(0xFFD9701C),
    primaryDeep: Color(0xFFC55F12),
    primarySoft: Color(0xFFFDEAD5),
    accent: Color(0xFFF0A24B),
    gold: Color(0xFFE9B638),
    amber: Color(0xFFA2520F),
    ink: Color(0xFF3A1F08),
    inkSoft: Color(0xFF55300E),
    energy: Color(0xFFF2A51F),
    energyLight: Color(0xFFFAD46E),
    water: Color(0xFF2EA3B8),
    steps: Color(0xFFC2662A),
    diet: Color(0xFFE9B638),
    protein: Color(0xFFA2520F),
    heat: [Color(0xFFFAEEDC), Color(0xFFF9D9AE), Color(0xFFF4B66E), Color(0xFFE88B35), Color(0xFFC55F12)],
  );

  /// Monsoon Arc: rain-washed green and teal.
  static const monsoon = Palette(
    background: Color(0xFFF0F6F3),
    surfaceHigh: Color(0xFFE1EEE8),
    stroke: Color(0xFFD2E3DB),
    shadow: Color(0xFF1C463B),
    textPrimary: Color(0xFF17302A),
    textSecondary: Color(0xFF45605A),
    textTertiary: Color(0xFF526D66),
    textMuted: Color(0xFF93AAA3),
    primary: Color(0xFF2B8570),
    primaryDeep: Color(0xFF227462),
    primarySoft: Color(0xFFDCEFE8),
    accent: Color(0xFF5FB59F),
    gold: Color(0xFF9BC37A),
    amber: Color(0xFF1F6253),
    ink: Color(0xFF0F2A25),
    inkSoft: Color(0xFF1A3F37),
    energy: Color(0xFF3FB3A0),
    energyLight: Color(0xFFA6E0D3),
    water: Color(0xFF3C8FC2),
    steps: Color(0xFF4F7F60),
    diet: Color(0xFF9BC37A),
    protein: Color(0xFF2E6A55),
    heat: [Color(0xFFE2EEE9), Color(0xFFC0E0D4), Color(0xFF8DCAB6), Color(0xFF52A890), Color(0xFF237563)],
  );
}
