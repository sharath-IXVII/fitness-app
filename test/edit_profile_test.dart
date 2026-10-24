import 'dart:convert';

import 'package:fitalarm/app.dart';
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the profile can be edited and targets follow', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({
      'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'phone', 'phone': '+919876543210'}),
      'profile.v1': jsonEncode({
        'name': 'Meera',
        'gender': 'female',
        'age': 30,
        'heightCm': 160,
        'weightKg': 60,
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
    await t.tap(find.byTooltip('Profile'));
    await _wait(t);
    expect(find.text('Stay fit'), findsOneWidget);

    await t.tap(find.text('Edit'));
    await _wait(t);
    await t.tap(find.text('Build muscle'));
    await t.tap(find.text('Eggetarian'));
    // Weight +1 kg (two half-kg steps).
    final plus = find.byIcon(Icons.add_rounded).hitTestable();
    await t.tap(plus.at(2));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(plus.at(2));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Save'));
    await _wait(t);

    final saved = jsonDecode(prefs.getString('profile.v1')!) as Map<String, dynamic>;
    expect(saved['goal'], 'buildMuscle');
    expect(saved['diet'], 'eggetarian');
    expect(saved['weightKg'], 61.0);
    expect(find.text('Build muscle'), findsOneWidget);
    expect(find.text('61.0 kg'), findsOneWidget);
  });
}
