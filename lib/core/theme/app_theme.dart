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
      splashFactory: InkRipple.splashFactory,
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
      timePickerTheme: const TimePickerThemeData(backgroundColor: AppColors.surface),
    );

    final body = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
    // Inter throughout. Weights are passed to GoogleFonts directly so the
    // matching bundled file is used rather than a synthesised bold.
    TextStyle t(TextStyle? b, FontWeight w, {double ls = 0, Color? color}) =>
        GoogleFonts.inter(textStyle: b, fontWeight: w, letterSpacing: ls, color: color);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: t(body.displayLarge, FontWeight.w700, ls: -1.5),
        displayMedium: t(body.displayMedium, FontWeight.w700, ls: -1.2),
        displaySmall: t(body.displaySmall, FontWeight.w700, ls: -1),
        headlineLarge: t(body.headlineLarge, FontWeight.w700, ls: -0.8),
        headlineMedium: t(body.headlineMedium, FontWeight.w700, ls: -0.6),
        headlineSmall: t(body.headlineSmall, FontWeight.w600, ls: -0.4),
        titleLarge: t(body.titleLarge, FontWeight.w600, ls: -0.3),
        titleMedium: t(body.titleMedium, FontWeight.w600, ls: -0.1),
        titleSmall: t(body.titleSmall, FontWeight.w600),
        labelLarge: t(body.labelLarge, FontWeight.w600),
        labelMedium: t(body.labelMedium, FontWeight.w500),
        labelSmall: t(body.labelSmall, FontWeight.w500),
        bodyMedium: t(body.bodyMedium, FontWeight.w400, color: AppColors.textSecondary),
        bodySmall: t(body.bodySmall, FontWeight.w400, color: AppColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
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
