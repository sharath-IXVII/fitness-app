import 'dart:math' as math;

import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/wellness/fitness_tests.dart';
import 'package:fitalarm/features/wellness/mind_games.dart';
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
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
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

  test('personal bests: highest score, or lowest time', () {
    final all = [
      for (final v in [7, 9, 5]) WellnessEntry(at: DateTime(2026), kind: 'memory', value: v),
      for (final v in [310, 245]) WellnessEntry(at: DateTime(2026), kind: 'focus', value: v),
    ];
    expect(bestOf(all, 'memory'), 9);
    expect(bestOf(all, 'focus', lowerIsBetter: true), 245);
    expect(bestOf(all, 'colour'), isNull);
  });

  testWidgets('memory: repeat the pattern, a mistake ends the game with a report', (t) async {
    final c = await pump(t, MemoryGameScreen(random: math.Random(3)));
    await t.tap(find.text('Start'));
    await t.pump();
    // Watch the first pattern (3 tiles): each time a tile lights up, note it.
    final seen = <int>[];
    int? prev;
    int? litNow() {
      for (var k = 0; k < 9; k++) {
        final box = t.widget<AnimatedContainer>(
          find.descendant(of: find.byKey(ValueKey('tile$k')), matching: find.byType(AnimatedContainer)),
        );
        if ((box.decoration! as BoxDecoration).boxShadow != null) return k;
      }
      return null;
    }

    for (var i = 0; i < 70; i++) {
      await t.pump(const Duration(milliseconds: 50));
      final now = litNow();
      if (now != null && now != prev) seen.add(now);
      prev = now;
    }
    expect(seen, hasLength(3));
    expect(find.text('Your turn'), findsOneWidget);
    // Repeat it, then tap a wrong tile on the next round.
    for (final k in seen) {
      await t.tap(find.byKey(ValueKey('tile$k')));
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pump(const Duration(seconds: 4));
    final wrong = [for (var k = 0; k < 9; k++) k].firstWhere((k) => k != seen.first);
    await t.tap(find.byKey(ValueKey('tile$wrong')));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Your report'), findsOneWidget);
    expect(c.read(wellnessProvider).single.kind, 'memory');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('focus: tapping 1 to 25 gives a time', (t) async {
    final c = await pump(t, FocusGameScreen(random: math.Random(1)));
    for (var n = 1; n <= 25; n++) {
      await t.tap(find.text('$n'));
      await t.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Your report'), findsOneWidget);
    final e = c.read(wellnessProvider).single;
    expect((e.kind, e.extra), ('focus', 0));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('colour clash: 30 seconds, right minus wrong', (t) async {
    final c = await pump(t, ColourGameScreen(random: math.Random(2)));
    await t.tap(find.text('Start'));
    await t.pump();
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Red'));
      await t.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 32; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Your report'), findsOneWidget);
    final e = c.read(wellnessProvider).single;
    expect(e.kind, 'colour');
    expect(e.extra, lessThanOrEqualTo(5));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });
}
