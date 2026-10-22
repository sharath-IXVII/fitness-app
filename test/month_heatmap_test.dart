import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:fitalarm/features/streaks/widgets/month_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows one month and pages back to earlier months', (t) async {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthHeatmap(
              scores: {
                dayOnly(lastMonth): const DayScore({DailyTask.workout, DailyTask.water, DailyTask.steps}),
              },
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text(DateFormat.yMMMM().format(thisMonth)), findsOneWidget);

    await t.tap(find.byTooltip('Previous month'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(find.text(DateFormat.yMMMM().format(lastMonth)), findsOneWidget);
    expect(find.textContaining('1 active'), findsOneWidget);

    await t.tap(find.byTooltip('Next month'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(find.text(DateFormat.yMMMM().format(thisMonth)), findsOneWidget);
  });
}
