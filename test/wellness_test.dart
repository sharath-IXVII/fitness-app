import 'package:fitalarm/core/storage.dart';
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
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: page)));
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
}
