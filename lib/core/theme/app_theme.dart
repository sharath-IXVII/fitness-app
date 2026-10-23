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
      colorScheme: ColorScheme.light(
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
    // Athletic condensed face for big numbers and headings, like a scoreboard.
    TextStyle sport(TextStyle? b, FontWeight w, {double ls = 0.2}) =>
        GoogleFonts.barlowCondensed(textStyle: b, fontWeight: w, letterSpacing: ls, height: 1.05);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: sport(body.displayLarge, FontWeight.w800, ls: -0.5),
        displayMedium: sport(body.displayMedium, FontWeight.w800, ls: -0.3),
        displaySmall: sport(body.displaySmall, FontWeight.w800),
        headlineLarge: sport(body.headlineLarge, FontWeight.w800),
        headlineMedium: sport(body.headlineMedium, FontWeight.w700),
        headlineSmall: sport(body.headlineSmall, FontWeight.w700),
        titleLarge: t(body.titleLarge, FontWeight.w600, ls: -0.3),
        titleMedium: t(body.titleMedium, FontWeight.w600, ls: -0.1),
        titleSmall: t(body.titleSmall, FontWeight.w600),
        labelLarge: t(body.labelLarge, FontWeight.w600),
        labelMedium: t(body.labelMedium, FontWeight.w500),
        labelSmall: t(body.labelSmall, FontWeight.w500),
        bodyMedium: t(body.bodyMedium, FontWeight.w400, color: AppColors.textSecondary),
        bodySmall: t(body.bodySmall, FontWeight.w400, color: AppColors.textTertiary),
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
        actionTextColor: AppColors.primary,
        contentTextStyle: body.bodyMedium?.copyWith(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
