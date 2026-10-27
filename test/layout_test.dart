import 'dart:convert';

import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/core/theme/app_theme.dart';
import 'package:fitalarm/features/health/food_guide_screen.dart';
import 'package:fitalarm/features/health/health_screen.dart';
import 'package:fitalarm/features/health/heart_rate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The new screens must fit small phones and large system text: no
/// overflowing stripes, no errors.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const sizes = [Size(320, 568), Size(360, 640), Size(412, 915)];
  final screens = <String, Widget>{
    'Health': const HealthScreen(),
    'Heart rate': const HeartRateScreen(),
    'Food guide': const FoodGuideScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    for (final size in sizes) {
      for (final scale in [1.0, 1.4]) {
        testWidgets('$name fits ${size.width.round()}x${size.height.round()} at text size $scale', (t) async {
          t.view.physicalSize = size * 2;
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          SharedPreferences.setMockInitialValues({
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
            // A reading of each kind, so every card is on screen.
            'health.readings.v1': jsonEncode([
              {'id': '1', 'k': 'bloodPressure', 'at': DateTime(2026, 3, 1, 8).millisecondsSinceEpoch, 's': 128, 'd': 82},
              {'id': '2', 'k': 'bloodPressure', 'at': DateTime(2026, 3, 1, 20).millisecondsSinceEpoch, 's': 122, 'd': 79},
              {'id': '3', 'k': 'glucose', 'at': DateTime(2026, 3, 1, 7).millisecondsSinceEpoch, 'v': 96, 'c': 'fasting'},
              {'id': '4', 'k': 'pulse', 'at': DateTime(2026, 3, 1, 7).millisecondsSinceEpoch, 'v': 72},
              {'id': '5', 'k': 'oxygen', 'at': DateTime(2026, 3, 1, 7).millisecondsSinceEpoch, 'v': 98},
            ]),
          });
          final prefs = await SharedPreferences.getInstance();
          await t.pumpWidget(
            ProviderScope(
              overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(body: screen),
              ),
            ),
          );
          for (var i = 0; i < 10; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          final first = t.takeException();
          if (first != null) debugPrint('OVERFLOW(top): ${first is FlutterError ? first.toStringDeep() : first}');
          expect(first, isNull);

          // Scroll to the bottom as well, in case only lower parts overflow.
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            for (var i = 0; i < 12; i++) {
              await t.drag(scrollable.first, const Offset(0, -500));
              await t.pump(const Duration(milliseconds: 100));
            }
            final later = t.takeException();
            if (later != null) debugPrint('OVERFLOW(scrolled): ${later is FlutterError ? later.toStringDeep() : later}');
            expect(later, isNull);
          }
        });
      }
    }
  }
}
