import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/i18n/i18n.dart';
import 'package:fitalarm/core/storage.dart';
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

/// Scrolls every scrollable on screen to the end, so lazy parts get built.
Future<void> _scrollAll(WidgetTester t) async {
  final widgets = [for (final e in find.byType(Scrollable).hitTestable().evaluate()) e.widget];
  for (final w in widgets) {
    final f = find.byWidget(w);
    if (f.evaluate().isEmpty) continue;
    for (var i = 0; i < 6; i++) {
      await t.drag(f.first, const Offset(0, -600), warnIfMissed: false);
      await _wait(t, 200);
    }
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => currentLang = AppLang.en);

  const tabs = {
    'kn': ['ಇಂದು', 'ವ್ಯಾಯಾಮಗಳು', 'ನನ್ನ ದಿನ', 'ಅಲಾರಂ', 'ಆಹಾರ'],
    'hi': ['आज', 'वर्कआउट', 'मेरा दिन', 'अलार्म', 'डाइट'],
  };
  for (final lang in tabs.keys) {
    for (final (size, scale) in [
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
      (const Size(412, 915), 1.0),
    ]) {
      testWidgets('the main pages fit in $lang at ${size.width.round()}x${size.height.round()}, text $scale', (
        t,
      ) async {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({
          'app.lang.v1': lang,
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
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWithValue(prefs),
              authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
            ],
            child: const FitTrackerApp(),
          ),
        );
        await _wait(t, 5600);
        expect(find.text(tabs[lang]!.first), findsWidgets); // "Today" in the bottom bar
        final errors = <String>[];
        for (final tab in tabs[lang]!) {
          await t.tap(find.text(tab).last);
          await _wait(t);
          await _scrollAll(t);
          final e = t.takeException();
          if (e is FlutterError) {
            final where = e.diagnostics.map((d) => d.toString()).where((l) => l.contains('file:///')).join(' ');
            errors.add('$tab: ${e.message.split('\n').first} $where');
          } else if (e != null) {
            errors.add('$tab: $e');
          }
        }
        expect(errors, isEmpty);
        // Let timers (countdowns, animations) finish.
        await t.pumpWidget(const SizedBox());
        await _wait(t, 3000);
      });
    }
  }
}
