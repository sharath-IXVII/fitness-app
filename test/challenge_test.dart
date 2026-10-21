import 'dart:convert';
import 'dart:math' as math;

import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/core/theme/app_theme.dart';
import 'package:fitalarm/features/alarm/alarm_scheduler.dart';
import 'package:fitalarm/features/alarm/domain/workout_alarm.dart';
import 'package:fitalarm/features/alarm/strict_mode.dart';
import 'package:fitalarm/features/challenge/challenge_screen.dart';
import 'package:fitalarm/features/challenge/domain/games.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Evaluates "a + b − c" / "a × b + c" left to right with × first.
int _eval(String expr) {
  final t = expr.split(' ');
  var terms = <int>[int.parse(t[0])];
  var ops = <String>[];
  for (var i = 1; i < t.length; i += 2) {
    final op = t[i], n = int.parse(t[i + 1]);
    if (op == '×') {
      terms[terms.length - 1] *= n;
    } else {
      ops.add(op);
      terms.add(n);
    }
  }
  var v = terms.first;
  for (var i = 0; i < ops.length; i++) {
    v = ops[i] == '+' ? v + terms[i + 1] : v - terms[i + 1];
  }
  return v;
}

Future<void> _wait(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('maths problems have non-negative answers that match the text', () {
    final rng = math.Random(7);
    for (final level in ChallengeLevel.values) {
      for (var i = 0; i < 300; i++) {
        final p = mathProblem(level, rng);
        expect(p.answer, greaterThanOrEqualTo(0), reason: p.text);
        expect(_eval(p.text), p.answer, reason: p.text);
      }
    }
  });

  test('memory patterns use distinct tiles inside the grid', () {
    final rng = math.Random(3);
    for (final level in ChallengeLevel.values) {
      final s = memorySpec(level);
      final p = memoryPattern(s.side, s.length + 1, rng);
      expect(p.toSet(), hasLength(s.length + 1));
      expect(p.every((t) => t >= 0 && t < s.side * s.side), isTrue);
    }
  });

  test('order grid holds each number once', () {
    final g = orderGrid(4, math.Random(1));
    expect(g.toSet(), {for (var i = 1; i <= 16; i++) i});
  });

  test('mixed plays every game once; workout plays none', () {
    expect(gamesFor(AlarmChallenge.mixed, math.Random(2)).toSet(), GameKind.values.toSet());
    expect(gamesFor(AlarmChallenge.workout, math.Random(2)), isEmpty);
  });

  test('strict and challenge settings survive json and the ring payload', () {
    final a = WorkoutAlarm(
      id: 3,
      time: const TimeOfDay(hour: 6, minute: 0),
      routineId: 'core',
      strict: true,
      challenge: AlarmChallenge.memory,
      level: ChallengeLevel.hard,
    );
    final back = WorkoutAlarm.fromJson(a.toJson());
    expect(back.strict, isTrue);
    expect(back.challenge, AlarmChallenge.memory);
    expect(back.level, ChallengeLevel.hard);
    expect(back.allowedSnoozes, 0, reason: 'strict implies no snooze');

    final info = RingInfo.fromPayload(RingInfo.forAlarm(a, 'core').toPayload())!;
    expect(info.strict, isTrue);
    expect(info.hardMode, isTrue);
    expect(info.challenge, AlarmChallenge.memory);
    expect(info.level, ChallengeLevel.hard);

    // Older saved alarms without the new fields still load.
    final old = WorkoutAlarm.fromJson(jsonDecode('{"id":1,"time":360,"days":[],"routine":"beginner"}'));
    expect(old.strict, isFalse);
    expect(old.challenge, AlarmChallenge.workout);
  });

  testWidgets('solving the number-order game turns a strict alarm off', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const ring = RingInfo(
      alarmId: 1,
      routineId: 'beginner',
      label: 'Study time',
      strict: true,
      hardMode: true,
      challenge: AlarmChallenge.order,
      level: ChallengeLevel.easy,
    );
    await t.runAsync(() => StrictMode.engage(prefs, ring));
    expect(StrictMode.pending(prefs)?.label, 'Study time');

    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChallengeScreen(
            args: ChallengeArgs(challenge: AlarmChallenge.order, level: ChallengeLevel.easy, ring: ring),
          ),
        ),
      ),
    );
    await _wait(t);
    expect(find.text('Strict mode'), findsOneWidget);
    expect(find.text('Tap 1'), findsOneWidget);

    // A wrong tap doesn't advance.
    await t.tap(find.text('5'));
    await _wait(t, 200);
    expect(find.text('Tap 1'), findsOneWidget);

    for (var n = 1; n <= 9; n++) {
      await t.tap(find.text('$n').last);
      await t.pump(const Duration(milliseconds: 50));
    }
    await _wait(t, 800);
    expect(find.text("Alarm off. You're awake."), findsOneWidget);
    expect(StrictMode.isActive(prefs), isFalse);
  });

  testWidgets('maths practice: wrong answers are rejected, right ones advance', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChallengeScreen(
            args: ChallengeArgs(challenge: AlarmChallenge.math, level: ChallengeLevel.easy),
          ),
        ),
      ),
    );
    await _wait(t);
    String problem() => t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .firstWhere((s) => RegExp(r'^\d+ [+−×] \d+').hasMatch(s));

    Future<void> type(int n) async {
      for (final d in '$n'.split('')) {
        await t.tap(find.bySemanticsLabel(d).last);
        await t.pump();
      }
      await t.tap(find.bySemanticsLabel('Check'));
      await _wait(t, 400);
    }

    await type(_eval(problem()) + 1);
    expect(find.text('Not quite — try again'), findsOneWidget);
    for (var i = 0; i < mathCount(ChallengeLevel.easy); i++) {
      await type(_eval(problem()));
    }
    await _wait(t, 400);
    expect(find.text('Nicely done'), findsOneWidget);
  });
}
