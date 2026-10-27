import 'package:fitalarm/core/theme/app_theme.dart';
import 'package:fitalarm/core/widgets/form_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<List<TimeOfDay>> open(WidgetTester t, TimeOfDay start) async {
    final seen = <TimeOfDay>[];
    var time = start;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => SizedBox(
              height: 170,
              child: ClockWheels(
                time: time,
                onChanged: (v) => set(() {
                  time = v;
                  seen.add(v);
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    return seen;
  }

  testWidgets('shows a 12-hour clock with AM / PM, never 13 to 23', (t) async {
    await open(t, const TimeOfDay(hour: 15, minute: 5));
    expect(find.text('3'), findsWidgets);
    expect(find.text('PM'), findsWidgets);
    expect(find.text('15'), findsNothing);
    expect(find.text('13'), findsNothing);
  });

  testWidgets('midnight reads 12 AM and noon reads 12 PM', (t) async {
    await open(t, const TimeOfDay(hour: 0, minute: 0));
    expect(find.text('12'), findsWidgets);
    expect(find.text('AM'), findsWidgets);
    await open(t, const TimeOfDay(hour: 12, minute: 0));
    expect(find.text('PM'), findsWidgets);
  });

  testWidgets('switching PM to AM keeps the hour and minute', (t) async {
    final seen = await open(t, const TimeOfDay(hour: 15, minute: 5));
    await t.drag(find.text('PM').first, const Offset(0, 80));
    await t.pumpAndSettle();
    expect(seen.last, const TimeOfDay(hour: 3, minute: 5));
  });
}
