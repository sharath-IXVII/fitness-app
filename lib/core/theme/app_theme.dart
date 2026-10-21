import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surfaceContainerHighest: AppColors.surfaceHigh,
        outline: AppColors.stroke,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      splashFactory: InkSparkle.splashFactory,
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
      timePickerTheme: const TimePickerThemeData(backgroundColor: AppColors.surface),
    );

    final body = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
    // Fraunces, a soft editorial serif, gives headings a character no other
    // fitness app has; Inter keeps body text crisp. Weights are passed to
    // GoogleFonts directly so the matching bundled file is used.
    TextStyle serif(TextStyle? b, FontWeight w, [double ls = -0.4]) =>
        GoogleFonts.fraunces(textStyle: b, fontWeight: w, letterSpacing: ls);
    TextStyle sans(TextStyle? b, FontWeight w, {Color? color}) =>
        GoogleFonts.inter(textStyle: b, fontWeight: w, color: color);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: serif(body.displayLarge, FontWeight.w700, -1),
        displayMedium: serif(body.displayMedium, FontWeight.w700, -0.8),
        displaySmall: serif(body.displaySmall, FontWeight.w700, -0.6),
        headlineLarge: serif(body.headlineLarge, FontWeight.w700, -0.5),
        headlineMedium: serif(body.headlineMedium, FontWeight.w700, -0.5),
        headlineSmall: serif(body.headlineSmall, FontWeight.w600),
        titleLarge: serif(body.titleLarge, FontWeight.w600, -0.2),
        titleMedium: sans(body.titleMedium, FontWeight.w600),
        titleSmall: sans(body.titleSmall, FontWeight.w600),
        labelLarge: sans(body.labelLarge, FontWeight.w600),
        labelMedium: sans(body.labelMedium, FontWeight.w500),
        labelSmall: sans(body.labelSmall, FontWeight.w500),
        bodyMedium: sans(body.bodyMedium, FontWeight.w400, color: AppColors.textSecondary),
        bodySmall: sans(body.bodySmall, FontWeight.w400, color: AppColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: body.bodyMedium?.copyWith(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
