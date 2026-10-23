import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/core/theme/app_colors.dart';
import 'package:fitalarm/core/theme/palette.dart';
import 'package:fitalarm/features/arcs/arc_providers.dart';
import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _wait(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the look follows the arc, and previewing another arc repaints the app', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({
      'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'phone', 'phone': '+919876543210'}),
      'profile.v1': jsonEncode({
        'name': 'Asha',
        'gender': 'female',
        'age': 24,
        'heightCm': 162,
        'weightKg': 64,
        'goal': 'maintain',
        'activity': 'light',
        'diet': 'veg',
        'level': 'beginner',
        'wake': 390,
        'sleep': 1380,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const FitTrackerApp()));
    await _wait(t, 3400);

    final season = ArcPeriod.of(DateTime.now()).season;
    expect(identical(AppColors.palette, season.palette), isTrue);
    expect(find.text(season.title), findsWidgets); // the arc card on Today

    await container.read(arcPreviewProvider.notifier).set(Season.monsoon);
    await _wait(t);
    expect(identical(AppColors.palette, Palette.monsoon), isTrue);
    expect(find.text('Monsoon Arc'), findsOneWidget);
    expect(prefs.getString('arc.preview.v1'), 'monsoon');

    await t.tap(find.text('Monsoon Arc'));
    await _wait(t);
    expect(find.text('Badges this arc'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Automatic'), 300, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('Automatic'));
    await _wait(t);
    expect(identical(AppColors.palette, season.palette), isTrue);
    expect(prefs.getString('arc.preview.v1'), isNull);
  });
}
