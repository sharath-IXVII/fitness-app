import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.lime,
        secondary: AppColors.mint,
        surface: AppColors.surface,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    final body = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
    final display = GoogleFonts.soraTextTheme(body);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.5),
        displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
        displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: body.bodyMedium?.copyWith(color: AppColors.textSecondary),
        bodySmall: body.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
          borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
        ),
      ),
    );
  }
}
