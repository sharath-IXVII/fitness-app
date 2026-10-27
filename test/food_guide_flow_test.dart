import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/health/food_guide_screen.dart';
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

  testWidgets('Food guide: rank by a nutrient, open a food, compare two foods', (t) async {
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

    // The Health tab shows a first-time guide, and it can be dismissed for good.
    // Health opens from the card on Today.
    final today = find.byType(Scrollable).hitTestable().first;
    await t.scrollUntilVisible(find.text('Health check'), 200, scrollable: today);
    await t.drag(today, const Offset(0, -240));
    await _wait(t, 300);
    await t.tap(find.text('Health check'));
    await _wait(t);
    expect(find.text('Start here: 3 taps'), findsOneWidget);
    await t.tap(find.text('Got it'));
    await _wait(t, 300);
    expect(find.text('Start here: 3 taps'), findsNothing);
    expect(prefs.getBool('guide.health.v1'), isTrue);

    await t.scrollUntilVisible(
      find.text('Food guide'),
      200,
      scrollable: find.descendant(of: find.byType(HealthScreen), matching: find.byType(Scrollable)).first,
    );
    await t.ensureVisible(find.text('Food guide'));
    await _wait(t, 300);
    await t.tap(find.text('Food guide'));
    await _wait(t);
    expect(find.text('How to use the food guide'), findsOneWidget);
    await t.tap(find.text('Got it'));
    await _wait(t, 300);

    // Protein is the default view; switching to vitamin C puts guava on top.
    await t.scrollUntilVisible(
      find.text('Vitamin C'),
      120,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal),
    );
    await t.tap(find.text('Vitamin C'));
    await _wait(t, 300);
    expect(find.text('Guava'), findsOneWidget);
    expect(find.text('228 mg'), findsOneWidget);

    // Opening a food shows everything in 100 g.
    await t.tap(find.text('Guava'));
    await _wait(t);
    expect(find.textContaining('In 100 g of raw guava'), findsOneWidget);
    expect(find.text('Fibre'), findsOneWidget);
    await t.tapAt(const Offset(195, 60)); // outside the sheet closes it
    await _wait(t);

    // Back to the top of the page, where the Rank / Compare switch is.
    await t.drag(
      find.descendant(of: find.byType(FoodGuideScreen), matching: find.byType(Scrollable)).first,
      const Offset(0, 800),
    );
    await _wait(t, 300);

    // Compare watermelon with sunflower seeds: more water in one, more fat in the other.
    await t.tap(find.text('Compare'));
    await _wait(t, 300);
    await t.tap(find.text('Food 1'));
    await _wait(t);
    await t.enterText(find.byType(TextField), 'watermelon');
    await _wait(t, 300);
    await t.tap(find.text('Watermelon').last);
    await _wait(t);
    await t.tap(find.text('Food 2'));
    await _wait(t);
    await t.enterText(find.byType(TextField), 'sunflower');
    await _wait(t, 300);
    await t.tap(find.text('Sunflower seeds').last);
    await _wait(t);
    expect(find.text('91.4 g'), findsOneWidget); // watermelon water
    expect(find.text('4.7 g'), findsWidgets); // sunflower water
  });
}
