import 'dart:math' as math;

import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/wellness/fitness_tests.dart';
import 'package:fitalarm/features/wellness/wellness.dart';
import 'package:fitalarm/features/wellness/wellness_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('breaths a minute come from the time between taps', () {
    expect(breathsPerMinute([0, 4]), isNull); // too few
    expect(breathsPerMinute([0, 4, 8, 12, 16]), 15); // a breath every 4 s
    expect(breathsPerMinute([1, 6, 11, 16]), 12);
  });

  Future<ProviderContainer> pump(WidgetTester t, Widget page) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: page),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    return c;
  }

  testWidgets('a mood check-in is saved with its energy', (t) async {
    final c = await pump(t, const MoodScreen());
    await t.tap(find.text('🙂'));
    await t.pump();
    await t.tap(find.text('Save check-in'));
    await t.pump(const Duration(milliseconds: 300));
    final e = c.read(wellnessProvider).single;
    expect((e.kind, e.value, e.extra), ('mood', 4, 3));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('breathing logs whole minutes when stopped', (t) async {
    final c = await pump(t, const BreathingScreen());
    await t.scrollUntilVisible(find.text('Start'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Start'));
    for (var i = 0; i < 65; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.ensureVisible(find.text('Stop'));
    await t.tap(find.text('Stop'));
    await t.pump(const Duration(milliseconds: 300));
    expect(c.read(wellnessProvider).single.value, 1);
    expect(c.read(calmMinutesWeekProvider), 1);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  test('height from an A4 sheet on the wall', () {
    // Paper spans 0.30–0.40 of the photo, the person 0.05–0.62: 5.7 papers tall.
    final cm = heightFromMarks(refTop: 0.30, refBottom: 0.40, head: 0.05, feet: 0.62, refCm: 29.7);
    expect(cm, closeTo(169.29, 0.01));
    // On a 4000 px photo, a few pixels off on each mark is about 2 cm.
    final err = heightError(refPx: 400, personPx: 2280, heightCm: cm);
    expect(err, inInclusiveRange(1.5, 4.5));
  });

  test('steadiness drops as the phone sways more', () {
    expect(steadiness(0), 100);
    expect(steadiness(0.5), 73);
    expect(steadiness(5), 0);
  });

  testWidgets('reaction test: five taps on green give a report', (t) async {
    final c = await pump(t, ReactionTestScreen(random: math.Random(1)));
    for (var i = 0; i < 5; i++) {
      if (i == 0) {
        await t.tap(find.text('Tap to start'));
        await t.pump();
      }
      await t.pump(const Duration(seconds: 5)); // it turns green
      await t.pump(const Duration(milliseconds: 240));
      await t.tap(find.text('TAP!'));
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Your report'), findsOneWidget);
    expect(c.read(wellnessProvider).single.kind, 'reaction');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('balance test reports time held and steadiness', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        balanceSensorProvider.overrideWithValue(
          Stream.periodic(const Duration(milliseconds: 20), (_) => (0.3, 0.0, 0.0)),
        ),
      ],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: BalanceTestScreen()),
      ),
    );
    await t.tap(find.text('Start'));
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.ensureVisible(find.text('Stop'));
    await t.tap(find.text('Stop'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Your report'), findsOneWidget);
    final e = c.read(wellnessProvider).single;
    expect(e.kind, 'balance');
    expect(e.value, inInclusiveRange(10, 13));
    expect(e.extra, inInclusiveRange(83, 84)); // 0.3 m/s² of sway
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
