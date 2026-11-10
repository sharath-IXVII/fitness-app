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

  testWidgets('see the plan, set a goal, read an explainer; adding food is by snapping', (t) async {
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
        'goal': 'loseWeight',
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

    await t.tap(find.text('Diet').last);
    await _wait(t);
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('kcal left'), findsOneWidget);

    // Food is added by snapping the plate: each meal's button opens the scanner.
    expect(find.text('Snap'), findsWidgets);
    expect(find.text('Add'), findsNothing);

    expect(find.text("Today's plan"), findsNothing);

    // Set a weight goal.
    final setGoal = find.text('Set a weight goal');
    await t.scrollUntilVisible(setGoal, 200, scrollable: find.byType(Scrollable).hitTestable().first);
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 300));
    await _wait(t, 300);
    await t.tap(setGoal);
    await _wait(t);
    expect(find.text('Realistic pace'), findsOneWidget);
    await t.tap(find.text('4 weeks'));
    await _wait(t, 300);
    expect(find.text('Faster than is safe'), findsOneWidget);
    await t.tap(find.text('Set goal'));
    await _wait(t);
    expect(find.text('Capped for safety'), findsOneWidget);
    expect(find.text('Goal pace'), findsOneWidget);

    // Explainers.
    await t.tap(find.text('Protein').hitTestable().first);
    await _wait(t);
    expect(find.text('What is protein?'), findsOneWidget);
    await t.tapAt(const Offset(200, 40)); // close the explainer
    await _wait(t);
  });
}
