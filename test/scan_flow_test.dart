import 'dart:convert';
import 'dart:typed_data';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/scan/domain/scan_result.dart';
import 'package:fitalarm/features/scan/food_scanner.dart';
import 'package:fitalarm/features/scan/scan_screen.dart';
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

// A 1×1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FakeScanner implements FoodScanner {
  String? hint;

  @override
  Future<ScanResult> scan(Uint8List image, String mediaType, {String? hint}) async {
    this.hint = hint;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return ScanResult.fromJson({
      'is_food': true,
      'items': [
        {
          'name': 'Rajma curry',
          'portion': '1 katori',
          'grams': 180,
          'kcal': 240,
          'protein_g': 11,
          'carbs_g': 30,
          'fat_g': 8,
          'fiber_g': 9,
          'veg': 'vegan',
          'confidence': 'medium',
        },
        {
          'name': 'Steamed rice',
          'portion': '1 cup',
          'grams': 160,
          'kcal': 205,
          'protein_g': 4,
          'carbs_g': 45,
          'fat_g': 0.4,
          'fiber_g': 0.6,
          'veg': 'vegan',
          'confidence': 'high',
        },
        {
          'name': 'Chicken tikka',
          'portion': '4 pieces',
          'grams': 120,
          'kcal': 200,
          'protein_g': 28,
          'carbs_g': 4,
          'fat_g': 8,
          'fiber_g': 0,
          'veg': 'non_veg',
          'confidence': 'low',
        },
      ],
      'note': 'Oil in the curry is hard to judge.',
    });
  }
}

Map<String, Object> _seed() => {
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
};

Future<SharedPreferences> _pump(WidgetTester t, {FoodScanner? scanner, bool connected = true}) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(_seed());
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
        foodScannerProvider.overrideWithValue(connected ? scanner : null),
        pickImageProvider.overrideWithValue((_) async => (bytes: _png, mediaType: 'image/png')),
      ],
      child: const FitAlarmApp(),
    ),
  );
  await _wait(t, 3400);
  await t.tap(find.text('Diet').last);
  await _wait(t);
  await t.tap(find.bySemanticsLabel('Scan food'));
  await _wait(t);
  return prefs;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('scan a plate, adjust it and log it', (t) async {
    final scanner = _FakeScanner();
    final prefs = await _pump(t, scanner: scanner);
    expect(find.text('Photograph your plate'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'rajma chawal');
    await t.tap(find.text('Lunch'));
    await _wait(t, 200);
    await t.tap(find.text('Take photo'));
    await _wait(t, 200);
    expect(find.text('Reading your plate…'), findsOneWidget);
    await _wait(t, 800);
    expect(scanner.hint, 'rajma chawal');

    expect(find.text('645 kcal'), findsOneWidget);
    expect(find.text('Unsure'), findsOneWidget);
    expect(find.textContaining('may not fit your diet'), findsOneWidget);
    expect(find.text('Oil in the curry is hard to judge.'), findsOneWidget);

    // Drop the chicken, double the rice.
    await t.tap(find.byTooltip('Remove Chicken tikka'));
    await _wait(t, 300);
    expect(find.textContaining('may not fit your diet'), findsNothing);
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byIcon(Icons.add_rounded).hitTestable().at(1));
      await _wait(t, 300);
    }
    expect(find.text('2×'), findsOneWidget);
    expect(find.text('650 kcal'), findsOneWidget);

    await t.tap(find.text('Add to lunch'));
    await _wait(t);
    final key = prefs.getKeys().firstWhere((k) => k.startsWith('meals.v1.'));
    final saved = jsonDecode(prefs.getString(key)!) as List;
    expect(saved.map((e) => e['name']), ['Rajma curry', 'Steamed rice']);
    expect(saved.every((e) => e['meal'] == 'lunch' && e['source'] == 'scan'), isTrue);
    expect(saved[1]['servings'], 2.0);
    expect(find.text('Steamed rice'), findsOneWidget, reason: 'back on the diet screen');
  });

  testWidgets('without a backend the scanner explains setup and offers manual entry', (t) async {
    await _pump(t, connected: false);
    expect(find.text('Scanner not connected'), findsOneWidget);
    await t.tap(find.text('Add food manually'));
    await _wait(t);
    expect(find.text('Search foods'), findsOneWidget);
  });
}
