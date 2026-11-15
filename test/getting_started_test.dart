import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/home/getting_started.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:fitalarm/features/streaks/widgets/day_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 11, 15);

  group('first steps', () {
    test('nothing is ticked for someone brand new', () {
      expect(startStepsDone([DailyLog(date: day)], hasPlan: false), isEmpty);
    });

    test('each step ticks itself from what the app records, on any day', () {
      final done = startStepsDone([
        DailyLog(date: day, waterMl: 250, steps: 120),
        DailyLog(date: addDays(day, -1), steps: 800, workoutDone: true),
      ], hasPlan: true);
      expect(done, {StartStep.water, StartStep.walk, StartStep.workout, StartStep.plan});
      expect(done, isNot(contains(StartStep.meal)));
    });
  });

  group('day celebration', () {
    test('each arc cheers in its own picture; a perfect day is the same everywhere', () {
      expect(dayWinText(DayWin.unlocked, Season.winter).$1, 'Ice broken!');
      expect(dayWinText(DayWin.unlocked, Season.monsoon).$1, 'Storm broken!');
      expect(dayWinText(DayWin.perfect, Season.summer).$1, 'Perfect day!');
    });

    testWidgets('it shows over the page, lets taps through and leaves by itself', (t) async {
      var taps = 0;
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return Center(
                  child: FilledButton(onPressed: () => taps++, child: const Text('Under')),
                );
              },
            ),
          ),
        ),
      );
      showDayCelebration(ctx, DayWin.unlocked, Season.winter);
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Ice broken!'), findsOneWidget);
      await t.tap(find.text('Under'), warnIfMissed: false);
      expect(taps, 1);
      await t.pumpAndSettle();
      expect(find.text('Ice broken!'), findsNothing);
    });
  });
}
