import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:fitalarm/features/wrapped/domain/arc_wrapped.dart';
import 'package:fitalarm/features/wrapped/wrapped_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final winter = ArcPeriod(Season.forMonth(11), 2026);
  final logs = {
    for (var d = 1; d <= 10; d++)
      DateTime(2026, 11, d): DailyLog(
        date: DateTime(2026, 11, d),
        workoutDone: d.isEven,
        steps: d * 1000,
        waterMl: 2000,
        mealsLogged: 3,
      ),
    // Outside the Arc: not counted.
    DateTime(2026, 9, 1): DailyLog(date: DateTime(2026, 9, 1), steps: 99999),
  };
  final full = DayScore({...DailyTask.values});
  final scores = {
    for (final d in logs.keys) d: d.month == 11 && d.day <= 4 ? full : const DayScore({DailyTask.water}),
  };

  test('the Wrapped numbers cover only the Arc', () {
    final w = ArcWrapped.of(
      winter,
      logs,
      scores,
      mealNames: {
        DateTime(2026, 11, 2): ['Dal', 'Rice', 'Dal'],
        DateTime(2026, 11, 3): ['Dal', 'Roti'],
        DateTime(2026, 8, 3): ['Pizza', 'Pizza', 'Pizza', 'Pizza'],
      },
    );
    expect(w.activeDays, 10);
    expect(w.perfectDays, 4);
    expect(w.workouts, 5);
    expect(w.steps, 55000);
    expect(w.bestDay, (DateTime(2026, 11, 10), 10000));
    expect(w.topFoods.first, 'Dal');
    expect(w.topFoods, isNot(contains('Pizza')));
    expect(w.bestStreak, 4);
    expect(w.isEmpty, isFalse);
  });

  testWidgets('every Wrapped card fits', (t) async {
    final w = ArcWrapped.of(
      winter,
      logs,
      scores,
      mealNames: {
        DateTime(2026, 11, 2): ['Paneer butter masala with butter naan', 'Rice', 'Dal'],
      },
      tier: ArcTier.master,
    );
    for (final card in wrappedCards(w)) {
      await t.pumpWidget(MaterialApp(home: Center(child: card)));
      expect(t.takeException(), isNull);
    }
  });
}
