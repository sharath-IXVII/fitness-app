import 'package:fitalarm/core/router.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/alarm/alarm_scheduler.dart';
import 'package:fitalarm/features/alarm/domain/workout_alarm.dart';
import 'package:fitalarm/features/alarm/sleep_mode.dart';
import 'package:fitalarm/features/alarm/sleep_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutAlarm _bedtime({bool strict = false, int end = 180}) => WorkoutAlarm(
  id: 5,
  time: const TimeOfDay(hour: 22, minute: 30),
  routineId: 'beginner',
  days: const {1, 2, 3, 4, 5, 6, 7},
  label: 'Bedtime',
  kind: AlarmKind.sleep,
  strict: strict,
  sleepEnd: end,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('bedtime alarm', () {
    test('Sleep mode ends at the next 3:00 AM after bedtime', () {
      final a = _bedtime();
      expect(a.sleepEndAfter(DateTime(2026, 10, 21, 22, 30)), DateTime(2026, 10, 22, 3, 0));
      // An after-midnight bedtime ends the same night.
      expect(a.sleepEndAfter(DateTime(2026, 10, 22, 1, 15)), DateTime(2026, 10, 22, 3, 0));
      // Exactly at the end time, the next one is a day later.
      expect(a.sleepEndAfter(DateTime(2026, 10, 22, 3, 0)), DateTime(2026, 10, 23, 3, 0));
      expect(_bedtime(end: 5 * 60 + 30).sleepEndAfter(DateTime(2026, 10, 21, 23, 0)), DateTime(2026, 10, 22, 5, 30));
    });

    test('it rings like any alarm, but blocking apps never removes the way to stop it', () {
      final a = _bedtime(strict: true).copyWith(maxSnoozes: 1);
      expect(a.isSleep, isTrue);
      expect(a.noEscape, isFalse);
      expect(a.allowedSnoozes, 1);
      expect(a.nextOccurrence(DateTime(2026, 10, 21, 20, 0)), DateTime(2026, 10, 21, 22, 30));
    });

    test('kind and end time survive saving and the ring payload', () {
      final a = _bedtime(strict: true, end: 200);
      final back = WorkoutAlarm.fromJson(a.toJson());
      expect(back.kind, AlarmKind.sleep);
      expect(back.sleepEnd, 200);
      expect(back.strict, isTrue);
      final ring = RingInfo.fromPayload(RingInfo.forAlarm(a, 'beginner').toPayload())!;
      expect(ring.isSleep, isTrue);
      expect(ring.sleepEnd, 200);
      expect(ring.strict, isTrue);
      // Old saved alarms have no kind: they are wake-up alarms.
      final old = a.toJson()
        ..remove('kind')
        ..remove('sleepEnd');
      expect(WorkoutAlarm.fromJson(old).kind, AlarmKind.wake);
      expect(WorkoutAlarm.fromJson(old).sleepEnd, WorkoutAlarm.defaultSleepEnd);
    });
  });

  group('Sleep mode session', () {
    test('a live session stays; one past its end time is released on the next start', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 10, 22, 1, 0);
      await SleepMode.start(prefs, end: DateTime(2026, 10, 22, 3, 0), block: true);
      final live = await SleepMode.reconcile(prefs, now: now);
      expect(live, isNotNull);
      expect(live!.block, isTrue);
      expect(live.end, DateTime(2026, 10, 22, 3, 0));

      final late = await SleepMode.reconcile(prefs, now: DateTime(2026, 10, 22, 3, 0, 1));
      expect(late, isNull);
      expect(prefs.containsKey(SleepMode.activeKey), isFalse);
    });

    test('with nothing saved there is no session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(await SleepMode.reconcile(prefs), isNull);
    });
  });

  group('screens', () {
    Future<GoRouter> pump(WidgetTester t, Widget home) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          GoRoute(
            path: Routes.home,
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: Routes.sleep,
            builder: (_, s) => SleepModeScreen(args: s.extra! as SleepArgs),
          ),
        ],
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      return router;
    }

    testWidgets('the bedtime ring explains what Sleep mode will do', (t) async {
      await pump(t, SleepRing(info: RingInfo.forAlarm(_bedtime(strict: true), 'beginner')));
      expect(find.text('Time to sleep'), findsOneWidget);
      expect(find.text('Start sleep mode'), findsOneWidget);
      expect(find.textContaining('Other apps are blocked until'), findsOneWidget);
      expect(find.textContaining('restart your phone'), findsOneWidget);
      expect(find.text('Skip tonight'), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // dispose the screen
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('a gentle bedtime says you can leave any time', (t) async {
      await pump(t, SleepRing(info: RingInfo.forAlarm(_bedtime(), 'beginner')));
      expect(find.textContaining('You can leave it any time'), findsOneWidget);
      expect(find.textContaining('blocked'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('blocking Sleep mode offers only the phone and the emergency number, with no exit', (t) async {
      final router = await pump(t, const SizedBox());
      final end = DateTime.now().add(const Duration(hours: 5));
      router.go(Routes.sleep, extra: SleepArgs(end: end, block: true));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Sleep mode'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Emergency 112'), findsOneWidget);
      expect(find.textContaining('restarting your phone unlocks everything'), findsOneWidget);
      expect(find.text('End sleep mode'), findsNothing);
      await t.pumpWidget(const SizedBox()); // dispose the screen
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('gentle Sleep mode can be ended, and ends itself at the end time', (t) async {
      final router = await pump(t, const SizedBox());
      router.go(Routes.sleep, extra: SleepArgs(end: DateTime.now().add(const Duration(hours: 5)), block: false));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('End sleep mode'), findsOneWidget);
      expect(find.text('Emergency 112'), findsNothing);
      await t.tap(find.text('End sleep mode'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('HOME'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  });
}
