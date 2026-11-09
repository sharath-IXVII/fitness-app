import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/activity/skipping_screen.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:fitalarm/features/clubs/gps.dart';
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

/// A jog north at about 10 km/h with the chip's speed, a reading a second.
class _FakeGps extends Gps {
  const _FakeGps();

  @override
  Future<String?> ensure() async => null;

  @override
  Stream<GpsFix> track() async* {
    for (var i = 0; i < 300; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      yield GpsFix(12.97 + i * 0.000025, 77.59, 6, DateTime(2026, 11, 9, 6).add(Duration(seconds: i)), speed: 2.8);
    }
  }
}

Future<SharedPreferences> _open(WidgetTester t, {Stream<(double, double, double, DateTime)>? sensor}) async {
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
        gpsProvider.overrideWithValue(const _FakeGps()),
        if (sensor != null) skipSensorProvider.overrideWithValue(sensor),
      ],
      child: const FitTrackerApp(),
    ),
  );
  await _wait(t, 5600);
  await t.tap(find.text('Workouts').last);
  await _wait(t);
  return prefs;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a run on your own: GPS, go, finish, see it in history', (t) async {
    final prefs = await _open(t);
    await t.tap(find.text('Run').first);
    await _wait(t, 600);
    expect(find.textContaining('GPS: Strong'), findsOneWidget);
    await t.tap(find.text('Start'));
    await _wait(t, 4000);
    expect(find.text('Pause'), findsOneWidget);
    await t.tap(find.text('Finish'));
    await _wait(t, 300);
    expect(find.text('Finish?'), findsOneWidget);
    await t.tap(find.text('Finish').last);
    await _wait(t);
    // The summary card: an early-morning run.
    expect(find.text('Morning run').evaluate().isNotEmpty || find.textContaining(' run').evaluate().isNotEmpty, isTrue);
    final saved = jsonDecode(prefs.getString('activities.v1')!) as List;
    expect(saved.single['k'], ActivityKind.run.name);
    expect(saved.single['d'] as int, greaterThan(100));
  });

  testWidgets('skipping is counted from the motion sensor', (t) async {
    Stream<(double, double, double, DateTime)> jumps() async* {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final spike = i.isEven ? 14.0 : 0.5;
        yield (spike, 0.2, 0.2, DateTime(2026).add(Duration(milliseconds: i * 300)));
      }
    }

    await _open(t, sensor: jumps());
    await t.tap(find.text('Skipping'));
    await _wait(t);
    await t.tap(find.text('50'));
    await t.tap(find.text('Start'));
    await _wait(t, 2500);
    expect(find.text('20'), findsOneWidget);
    await t.tap(find.text('Stop'));
    await _wait(t);
    expect(find.text('20 skips! 🎉'), findsOneWidget);
  });
}
