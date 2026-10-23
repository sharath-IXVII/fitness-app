import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/arcs/widgets/arc_calendar.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the whole arc is shown; days unlock at 3 goals; earlier arcs can be browsed', (t) async {
    t.view.physicalSize = const Size(390, 844) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final today = dayOnly(DateTime.now());
    final arc = ArcPeriod.of(today);
    SharedPreferences.setMockInitialValues({'app.firstUse.v1': DateTime(2020).toIso8601String()});
    final prefs = await SharedPreferences.getInstance();
    final scores = {
      today: const DayScore({DailyTask.workout, DailyTask.water}),
      arc.start: const DayScore({DailyTask.workout, DailyTask.water, DailyTask.steps}),
    };
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ArcCalendar(scores: scores),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));

    expect(find.text(arc.label), findsOneWidget);
    expect(find.byType(ArcDayCell), findsNWidgets(arc.totalDays));
    final first = t.widget<ArcDayCell>(find.byType(ArcDayCell).first);
    expect(first.unlocked, today == arc.start ? isFalse : isTrue);

    await t.tap(find.byType(ArcDayCell).at(today.difference(arc.start).inDays));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 more to ${arc.season.unlockVerb}'), findsOneWidget);

    await t.tap(find.byTooltip('Previous arc'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(arc.previous.label), findsOneWidget);
    expect(find.byType(ArcDayCell), findsNWidgets(arc.previous.totalDays));
  });
}
