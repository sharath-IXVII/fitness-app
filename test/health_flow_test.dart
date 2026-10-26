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

  testWidgets('Health tab: add readings, see how they sort, get a warning for a dangerous one', (t) async {
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

    await t.tap(find.text('Health').last);
    await _wait(t);
    expect(find.text('7-day home blood pressure'), findsOneWidget);
    expect(find.textContaining('does not measure these itself'), findsOneWidget);

    // A normal reading.
    await t.tap(find.descendant(of: find.byType(GridView), matching: find.text('Blood pressure')));
    await _wait(t);
    await t.enterText(find.byType(TextField).at(0), '118');
    await t.enterText(find.byType(TextField).at(1), '76');
    await t.tap(find.text('Save reading'));
    await _wait(t);
    expect(find.textContaining('Saved: 118/76'), findsOneWidget);
    final list = find.descendant(of: find.byType(HealthScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Normal'), 200, scrollable: list);
    expect(find.text('Normal'), findsWidgets);
    // Back up to the tiles.
    await t.scrollUntilVisible(
      find.descendant(of: find.byType(GridView), matching: find.text('Blood pressure')),
      -300,
      scrollable: list,
    );

    // Numbers that cannot be right are refused.
    await t.tap(find.descendant(of: find.byType(GridView), matching: find.text('Blood pressure')));
    await _wait(t);
    await t.enterText(find.byType(TextField).at(0), '80');
    await t.enterText(find.byType(TextField).at(1), '90');
    await t.tap(find.text('Save reading'));
    await _wait(t, 300);
    expect(find.textContaining('top number must be higher'), findsOneWidget);

    // A dangerous reading shows a warning that tells the person what to do.
    await t.enterText(find.byType(TextField).at(0), '190');
    await t.enterText(find.byType(TextField).at(1), '125');
    await t.tap(find.text('Save reading'));
    await _wait(t);
    expect(find.text('Blood pressure: Very high'), findsOneWidget);
    expect(find.textContaining('112'), findsOneWidget);
    await t.tap(find.text('I understand'));
    await _wait(t);

    // Both readings are kept on this phone only.
    final saved = jsonDecode(prefs.getString('health.readings.v1')!) as List;
    expect(saved, hasLength(2));
    expect(saved.map((e) => (e as Map)['s']), containsAll([118, 190]));
  });
}
