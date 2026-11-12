import 'package:fitalarm/features/profile/domain/health_targets.dart';
import 'package:fitalarm/features/report/daily_report_screen.dart';
import 'package:fitalarm/features/report/domain/daily_report.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _t = HealthTargets(
  bmr: 1400,
  tdee: 1900,
  calories: 1800,
  proteinG: 60,
  carbsG: 220,
  fatG: 60,
  fiberG: 25,
  waterMl: 2500,
  steps: 8000,
  walkKm: 6,
  walkKcal: 300,
  bmi: 22,
  kcalPerKm: 50,
  strideM: 0.7,
);

void main() {
  test('score: 20 per goal, with part marks', () {
    final day = DateTime(2026, 11, 9);
    final full = DailyReport.of(
      DailyLog(date: day, workoutDone: true, waterMl: 3000, steps: 9000, mealsLogged: 3, proteinG: 70),
      _t,
      kcalEaten: 1750,
    );
    expect(full.score, 100);
    expect(full.tip, isNull);
    expect(full.verdict, contains('Champion'));

    final half = DailyReport.of(
      DailyLog(date: day, workoutDone: true, waterMl: 1250, steps: 4000, mealsLogged: 1, proteinG: 30),
      _t,
      kcalEaten: 900,
    );
    // 20 + 10 + 10 + 6.7 + 10
    expect(half.score, 57);
    expect(half.tip, contains('snap each meal')); // meals are the furthest behind

    final none = DailyReport.of(DailyLog(date: day), _t, kcalEaten: 0);
    expect(none.score, 0);
    expect(none.tip, contains('workout'));
  });

  testWidgets('the report card fits, even with big numbers and four plates', (t) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final r = DailyReport.of(
      DailyLog(date: DateTime(2026, 11, 9), waterMl: 4250, steps: 23456, mealsLogged: 5, proteinG: 120),
      _t,
      kcalEaten: 2650,
      snaps: 4,
      clubKm: 8.2,
      streak: 128,
    );
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: DailyReportCard(
            report: r,
            plates: [
              for (final (meal, dishes) in [
                ('Breakfast', 'Masala dosa, Coconut chutney, Sambar'),
                ('Lunch', 'Roti, Dal makhani, Paneer butter masala, Jeera rice'),
                ('Snacks', 'Banana'),
                ('Dinner', 'Chicken biryani, Raita, Gulab jamun'),
              ])
                (meal: meal, dishes: dishes, kcal: 650, photo: null),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('${r.score}'), findsOneWidget);
    expect(find.text('Roti, Dal makhani, Paneer butter masala, Jeera rice'), findsOneWidget); // what they ate
  });
}
