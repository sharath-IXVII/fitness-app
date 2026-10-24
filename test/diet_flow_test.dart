import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/diet/widgets/food_search_sheet.dart';
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

  testWidgets('log food, use the plan, set a goal, read an explainer', (t) async {
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

    // Search a veg food and add 1.5 servings to breakfast.
    await t.tap(find.text('Add').first);
    await _wait(t);
    await t.enterText(find.byType(TextField), 'poha');
    await _wait(t, 300);
    expect(find.textContaining('Chicken'), findsNothing, reason: 'veg users only see veg foods');
    await t.tap(find.text('Poha').last);
    await _wait(t);
    await t.tap(find.descendant(of: find.byType(ServingsStepper), matching: find.byIcon(Icons.add_rounded)));
    await _wait(t, 300);
    await t.tap(find.text('Add to breakfast'));
    await _wait(t);
    expect(find.text('Poha'), findsOneWidget);
    expect(find.text('1.5 servings · 8 g protein'), findsOneWidget);
    expect(jsonDecode(prefs.getString(prefs.getKeys().firstWhere((k) => k.startsWith('log.v1.')))!)['meals'], 1);

    // Log lunch straight from today's plan.
    final logLunch = find.byTooltip('Log lunch');
    await t.scrollUntilVisible(logLunch, 200, scrollable: find.byType(Scrollable).hitTestable().first);
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -300));
    await _wait(t, 300);
    await t.tap(logLunch);
    await _wait(t);
    expect(find.byTooltip('Log lunch'), findsNothing);

    // Set a weight goal.
    final setGoal = find.text('Set a weight goal');
    await t.scrollUntilVisible(setGoal, -200, scrollable: find.byType(Scrollable).hitTestable().first);
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

    // A custom food is saved to My foods and can be re-added from there.
    final add = find.text('Add').hitTestable();
    await t.scrollUntilVisible(add.first, 200, scrollable: find.byType(Scrollable).hitTestable().first);
    await t.tap(add.first);
    await _wait(t);
    final custom = find.text('Add a custom food');
    await t.scrollUntilVisible(custom, 300, scrollable: find.byType(Scrollable).hitTestable().last);
    await t.tap(custom);
    await _wait(t);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Protein bar');
    await t.enterText(fields.at(2), '210');
    await t.enterText(fields.at(3), '20');
    await t.pump();
    await t.tap(find.textContaining('Add to ').last);
    await _wait(t);
    expect(prefs.getString('myfoods.v1'), contains('Protein bar'));

    await t.tap(find.text('Add').hitTestable().first);
    await _wait(t);
    await t.tap(find.text('My foods'));
    await _wait(t, 300);
    expect(find.text('Protein bar'), findsWidgets);
  });
}
