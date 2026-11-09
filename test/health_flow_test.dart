import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/health/health_screen.dart';
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

  testWidgets('Health tab: wellness only, with the pulse history and no medical logs', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    SharedPreferences.setMockInitialValues({
      'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'google', 'name': 'Asha'}),
      'profile.v1': jsonEncode({
        'name': 'Asha',
        'gender': 'female',
        'age': 24,
        'heightCm': 162,
        'weightKg': 64,
        'goal': 'loseWeight',
        'activity': 'light',
        'diet': 'veg',
        'level': 'beginner',
        'wake': 390,
        'sleep': 1380,
      }),
      // An older version also kept blood pressure; it is no longer shown.
      'health.readings.v1': jsonEncode([
        {'id': '1', 'k': 'bloodPressure', 'at': DateTime(2026, 3, 1, 8).millisecondsSinceEpoch, 's': 128, 'd': 82},
        {'id': '2', 'k': 'pulse', 'at': DateTime(2026, 3, 1, 7).millisecondsSinceEpoch, 'v': 72},
      ]),
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

    // Health opens from the card on Today.
    final today = find.byType(Scrollable).hitTestable().first;
    await t.scrollUntilVisible(find.text('Health check'), 200, scrollable: today);
    await t.drag(today, const Offset(0, -240));
    await _wait(t, 300);
    await t.tap(find.text('Health check'));
    await _wait(t);
    final list = find.descendant(of: find.byType(HealthScreen), matching: find.byType(Scrollable)).first;
    expect(find.textContaining('not a medical device'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Resting pulse'), 200, scrollable: list);
    expect(find.text('Resting pulse'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    for (final gone in [
      'Blood pressure',
      'Blood sugar',
      'Oxygen (SpO₂)',
      '7-day home blood pressure',
      'Add a reading',
    ]) {
      expect(find.text(gone), findsNothing);
    }
  });
}
