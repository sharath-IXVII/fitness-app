import 'dart:convert';
import 'dart:typed_data';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/scan/food_recognizer.dart';
import 'package:fitalarm/features/scan/scan_screen.dart';
import 'package:fitalarm/features/snaps/snap_screen.dart';
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

/// Stands in for the on-device model: a confident butter chicken, a less
/// likely chicken curry, and a dish with no nutrition data.
Future<List<(String, double, int)>> _fakeClassify(Uint8List image) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return const [('Butter chicken', 0.71, 1), ('Chicken curry', 0.12, 0), ('Chaudin', 0.05, 0)];
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

final shared = <(Uint8List, String)>[];

Future<SharedPreferences> _pump(WidgetTester t, {bool model = true}) async {
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
        foodClassifierProvider.overrideWith((ref) async => model ? _fakeClassify : null),
        shareSnapProvider.overrideWithValue((png, text) async => shared.add((png, text))),
        pickImageProvider.overrideWithValue((_) async => (bytes: _png, mediaType: 'image/png')),
      ],
      child: const FitTrackerApp(),
    ),
  );
  await _wait(t, 5600);
  await t.tap(find.text('Diet').last);
  await _wait(t);
  await t.tap(find.bySemanticsLabel('Scan food'));
  await _wait(t);
  return prefs;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('recognise a dish on the phone, pick it, adjust the portion and log it', (t) async {
    final prefs = await _pump(t);
    expect(find.text('Photograph your food'), findsOneWidget);

    await t.tap(find.text('Lunch'));
    await _wait(t, 200);
    await t.tap(find.text('Take photo'));
    await _wait(t, 200);
    expect(find.text('Recognising your food…'), findsOneWidget);
    await _wait(t, 800);

    // The confident guess is added; the others are offered as chips.
    expect(find.text('Could be'), findsOneWidget);
    expect(find.text('Common dishes'), findsNothing); // the heading says "Not there? Common dishes"
    expect(find.text('Not there? Common dishes'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);
    expect(find.text('440 kcal'), findsWidgets);

    // Add the second guess too, then remove it again.
    await t.tap(find.text('Chicken curry').first);
    await _wait(t, 300);
    expect(find.text('740 kcal'), findsOneWidget);
    await t.tap(find.text('Chicken curry').first);
    await _wait(t, 300);
    expect(find.text('440 kcal'), findsWidgets);

    // One and a half servings.
    await t.scrollUntilVisible(
      find.byTooltip('Edit Butter chicken'),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await _wait(t, 300);
    await t.tap(find.byIcon(Icons.add_rounded).hitTestable().last);
    await _wait(t, 300);
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 2000)); // back to the top
    await _wait(t, 300);
    expect(find.text('660 kcal'), findsWidgets);

    await t.tap(find.text('Add to lunch'));
    await _wait(t);
    final key = prefs.getKeys().firstWhere((k) => k.startsWith('meals.v1.'));
    final saved = jsonDecode(prefs.getString(key)!) as List;
    expect(saved.single['name'], 'Butter chicken');
    expect(saved.single['servings'], 1.5);
    expect(saved.single['source'], 'scan');

    // The meal becomes a food snap: a FittArc story card that can be shared.
    expect(find.text('Food snap'), findsOneWidget);
    expect(find.text('FittArc'), findsOneWidget);
    expect(find.text('FOOD SNAP · LUNCH'), findsOneWidget);
    expect(find.text('≈ 660 kcal'), findsOneWidget);
    final snaps = jsonDecode(prefs.getString('snaps.v1')!) as List;
    expect(snaps.single['meal'], 'lunch');
    expect((snaps.single['items'] as List).single['n'], 'Butter chicken');
    expect((snaps.single['items'] as List).single['b'], [0, 0, 0.6, 0.6]); // seen in the top-left region
    await t.tap(find.text('Share to story or friends'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await _wait(t, 300);
    expect(shared, hasLength(1));
    expect(shared.single.$2, contains('FittArc'));
    expect(shared.single.$1.sublist(1, 4), 'PNG'.codeUnits);

    // Back on Diet, today's snaps show it.
    await t.pageBack();
    await _wait(t);
    expect(find.text("Today's snaps (1)"), findsOneWidget);
  });

  testWidgets('without the model the scanner offers manual entry', (t) async {
    await _pump(t, model: false);
    expect(find.text('Food recognition unavailable'), findsOneWidget);
    await t.tap(find.text('Add food manually'));
    await _wait(t);
    expect(find.text('Search foods'), findsOneWidget);
  });
}
