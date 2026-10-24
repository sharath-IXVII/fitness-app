import 'dart:convert';

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/training/voice_coach.dart';
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

class _SilentCoach extends VoiceCoach {
  final said = <String>[];

  @override
  void say(String text) => said.add(text);
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

Future<(SharedPreferences, _SilentCoach)> _open(WidgetTester t) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(_seed());
  final prefs = await SharedPreferences.getInstance();
  final coach = _SilentCoach();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
        voiceCoachProvider.overrideWithValue(coach),
      ],
      child: const FitTrackerApp(),
    ),
  );
  await _wait(t, 5600);
  await t.tap(find.text('Workouts').last);
  await _wait(t);
  return (prefs, coach);
}

/// Skips through every exercise and rest until the finish screen.
Future<void> _skipThrough(WidgetTester t) async {
  for (var guard = 0; guard < 80 && find.textContaining('complete!').evaluate().isEmpty; guard++) {
    final skipRest = find.text('Skip');
    if (skipRest.evaluate().isNotEmpty) {
      await t.tap(skipRest.last);
    } else {
      await t.tap(find.byTooltip('Skip exercise').last);
    }
    await _wait(t, 400);
  }
  await _wait(t, 600);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('pick a body part and level, play the workout, and it is saved', (t) async {
    final (prefs, coach) = await _open(t);
    expect(find.text('30-day challenges'), findsOneWidget);
    expect(find.text('Train by body part'), findsOneWidget);

    await t.tap(find.text('Biceps'));
    await _wait(t);
    expect(find.text('Choose your level'), findsOneWidget);
    await t.tap(find.text('Beginner'));
    await _wait(t);
    expect(find.text('Biceps · Beginner'), findsOneWidget);
    expect(find.textContaining('You will need'), findsOneWidget);

    await t.tap(find.text('Start workout'));
    await _wait(t);
    expect(find.text('GET READY'), findsOneWidget);
    expect(coach.said.first, contains('Jumping jacks'));

    await t.tap(find.text("I'm ready, start"));
    await _wait(t, 400);
    // A timed move counts down by itself.
    expect(find.text('30'), findsOneWidget);
    await _wait(t, 2100);
    expect(find.text('28'), findsOneWidget);

    await _skipThrough(t);
    expect(find.text('Workout complete!'), findsOneWidget);
    expect(prefs.getString('training.v1'), contains('Biceps · Beginner'));
    // Today's workout goal is ticked.
    final today = prefs.getKeys().where((k) => k.startsWith('log.')).map(prefs.getString);
    expect(today.any((v) => v!.contains('"workout":true')), isTrue);

    expect(find.textContaining('Achievement unlocked'), findsOneWidget);
    await _wait(t, 5000); // let the achievement notice go
    await t.tap(find.text('Done'));
    await _wait(t);
    await t.scrollUntilVisible(find.text('Recent'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Biceps · Beginner'), findsOneWidget);
    await _wait(t, 1500);
  });

  testWidgets('a rep exercise finishes with Done, and quitting asks first', (t) async {
    await _open(t);
    await t.scrollUntilVisible(find.text('Morning warm-up'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Morning warm-up'));
    await _wait(t);
    await t.tap(find.text('Start workout'));
    await _wait(t);
    await t.tap(find.text("I'm ready, start"));
    await _wait(t, 400);
    await t.tap(find.byTooltip('Skip exercise').last); // march → rest
    await _wait(t, 400);
    expect(find.text('REST'), findsOneWidget);
    expect(find.text('Arm circles'), findsOneWidget);

    await t.tap(find.byTooltip('Quit workout'));
    await _wait(t, 400);
    expect(find.text('Quit workout?'), findsOneWidget);
    await t.tap(find.text('Keep going'));
    await _wait(t, 400);
    expect(find.text('REST'), findsOneWidget);

    // Jump ahead to the toe touches, a rep move.
    for (var i = 0; i < 2; i++) {
      final skipRest = find.text('Skip');
      if (skipRest.evaluate().isNotEmpty) {
        await t.tap(skipRest.last);
        await _wait(t, 400);
      }
      await t.tap(find.byTooltip('Skip exercise').last);
      await _wait(t, 400);
    }
    await t.tap(find.text('Skip').last);
    await _wait(t, 400);
    expect(find.text('Standing toe touches'), findsWidgets);
    expect(find.text('×8'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Done'));
    await _wait(t, 400);
    expect(find.text('REST'), findsOneWidget);

    await t.tap(find.byTooltip('Quit workout'));
    await _wait(t, 400);
    await t.tap(find.text('Quit'));
    await _wait(t);
    expect(find.text('Start workout'), findsOneWidget);
  });

  testWidgets('start a 30-day challenge and complete day 1', (t) async {
    final (prefs, _) = await _open(t);
    await t.tap(find.text('Full body 30 days').first);
    await _wait(t);
    await t.tap(find.text('Intermediate'));
    await _wait(t, 400);
    await t.tap(find.text('Start challenge'));
    await _wait(t);
    expect(find.text('Week 1'), findsOneWidget);
    expect(prefs.getString('training.v1'), contains('"level":"intermediate"'));

    await t.tap(find.text('Start day 1'));
    await _wait(t);
    expect(find.text('Full body 30 days · Day 1'), findsOneWidget);
    await t.tap(find.text('Start workout'));
    await _wait(t);
    await t.tap(find.text("I'm ready, start"));
    await _wait(t, 400);
    await _skipThrough(t);
    expect(find.text('Day 1 complete!'), findsOneWidget);
    expect(find.textContaining('1 of 30 days done'), findsOneWidget);
    expect(prefs.getString('training.v1'), contains('"done":[1]'));
  });

  testWidgets('the exercise library filters and shows how-to steps', (t) async {
    await _open(t);
    await t.scrollUntilVisible(find.text('Exercise library'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Exercise library'));
    await _wait(t);
    await t.enterText(find.byType(TextField), 'tricep');
    await _wait(t, 300);
    expect(find.text('Triceps dips'), findsOneWidget);
    expect(find.text('Squats'), findsNothing);
    await t.tap(find.text('Triceps dips'));
    await _wait(t);
    expect(find.text('How to do it'), findsOneWidget);
    expect(find.textContaining('chair'), findsWidgets);
  });
}
