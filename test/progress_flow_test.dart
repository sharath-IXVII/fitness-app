import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _wait(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('home shows level, weekly report and achievements; account can be deleted', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final today = DateTime.now();
    final key = DateFormat('yyyy-MM-dd');
    SharedPreferences.setMockInitialValues({
      'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'phone', 'phone': '+919876543210'}),
      'profile.v1': jsonEncode({
        'name': 'Ravi',
        'gender': 'male',
        'age': 28,
        'heightCm': 175,
        'weightKg': 70,
        'goal': 'maintain',
        'activity': 'light',
        'diet': 'nonVeg',
        'level': 'beginner',
        'wake': 360,
        'sleep': 1380,
      }),
      'achievements.seen.v1': <String>[],
      // Eight perfect days ending yesterday.
      for (var i = 1; i <= 8; i++)
        'log.v1.${key.format(DateTime(today.year, today.month, today.day - i))}': jsonEncode({
          'workout': true,
          'water': 5000,
          'steps': 12000,
          'meals': 4,
          'protein': 200,
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
    await _wait(t, 3400);

    expect(find.text('8 achievements unlocked'), findsOneWidget);
    expect(prefs.getStringList('achievements.seen.v1'), hasLength(8));
    await _wait(t, 5000); // let the snackbar go

    final scroll = find.byType(Scrollable).hitTestable().first;
    await t.scrollUntilVisible(find.text('Your week'), 200, scrollable: scroll);
    await t.drag(scroll, const Offset(0, -200));
    await _wait(t, 300);
    // 8 perfect days × 70 XP + streak bonus 1..8 = 596 XP → level 3 (300–599).
    expect(find.text('Level 3 · Regular'), findsOneWidget);
    expect(find.text('596 XP'), findsOneWidget);
    await t.tap(find.text('Your week'));
    await _wait(t);
    // The week ends today, which is still empty: 6 of 7 days → 86%.
    expect(find.text('An excellent week'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('7/7'), findsNothing);
    expect(find.text('6/7'), findsNWidgets(5));
    await t.pageBack();
    await _wait(t);

    await t.tap(find.text('8/12 Starter badges'));
    await _wait(t);
    expect(find.text('8 of 12 earned · +100 XP when all 12 are done'), findsOneWidget);
    expect(find.text('Perfect week'), findsOneWidget);
    await t.pageBack();
    await _wait(t);

    // The profile opens from the avatar at the top of Today.
    await t.scrollUntilVisible(
      find.byTooltip('Profile'),
      -200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 300));
    await _wait(t, 300);
    await t.tap(find.byTooltip('Profile'));
    await _wait(t);
    final me = find.byType(Scrollable).hitTestable().first;
    await t.scrollUntilVisible(find.text('Delete account'), 200, scrollable: me);
    await t.drag(me, const Offset(0, -300));
    await _wait(t, 300);
    await t.tap(find.text('Delete account'));
    await _wait(t, 400);
    await t.tap(find.text('Delete'));
    await _wait(t, 1500);
    expect(find.text('Create your account'), findsOneWidget);
    expect(prefs.getString('profile.v1'), isNull);
    expect(prefs.getKeys().where((k) => k.startsWith('log.v1.')), isEmpty);
    // Everything else stored is gone too. Only sign-in state and two
    // bookkeeping keys the app rewrites at once (no personal data) remain.
    const regenerated = {'app.firstUse.v1', 'achievements.seen.v1'};
    expect(prefs.getKeys().where((k) => !k.startsWith('auth.') && !regenerated.contains(k)), isEmpty);
    await _wait(t, 10500); // the wipe's clean-up timeout
  });
}
