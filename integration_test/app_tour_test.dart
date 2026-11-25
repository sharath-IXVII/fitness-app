// Walks through every screen of the real app on an Android phone (the
// emulator in .github/workflows/device-test.yml): real camera, sensors,
// notifications and storage. Saves a screenshot of each screen and a report
// of every error to the app's external files folder, which the workflow
// pulls off the phone. A demo account with sample data is used, so no
// Google sign-in is needed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/router.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/alarm/alarm_scheduler.dart';
import 'package:fitalarm/features/alarm/domain/workout_alarm.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/challenge/challenge_screen.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:fitalarm/features/diet/domain/meal_log.dart';
import 'package:fitalarm/features/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _key = GlobalKey();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tour every screen on a real phone', (t) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final out = Directory('${(await getExternalStorageDirectory())!.path}/tour');
    if (out.existsSync()) out.deleteSync(recursive: true);
    out.createSync(recursive: true);
    final report = <Map<String, Object?>>[];

    // Errors anywhere (widgets, plugins, async code) are recorded, not fatal,
    // so one broken screen doesn't hide the rest.
    final errors = <String>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);

    Future<void> settle([int ms = 1500]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name) async {
      await settle(300);
      try {
        final ro = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      } catch (e) {
        errors.add('screenshot $name: $e');
      }
    }

    Future<void> visit(String name, FutureOr<void> Function() open, {bool scroll = true, int wait = 2500}) async {
      final before = errors.length;
      try {
        await open();
        await settle(wait);
        final ex = t.takeException();
        if (ex != null) errors.add('$ex'.split('\n').first);
        await shot(name);
        if (scroll) {
          for (final part in ['b', 'c']) {
            final s = find.byType(Scrollable).hitTestable();
            if (s.evaluate().isEmpty) break;
            final st = t.state<ScrollableState>(s.first);
            if (st.position.axis != Axis.vertical || st.position.pixels >= st.position.maxScrollExtent - 4) break;
            st.position.jumpTo((st.position.pixels + 700).clamp(0, st.position.maxScrollExtent));
            await settle(800);
            await shot('${name}_$part');
          }
        }
      } catch (e) {
        errors.add('$e'.split('\n').first);
      }
      report.add({'screen': name, 'errors': errors.sublist(before)});
    }

    // ---- A user with some history: profile, 6 weeks of days, an alarm.
    final day = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    final seed = <String, Object>{
      'app.lang.v1': 'en',
      'intro.seen.v1': true,
      'perm.intro.v1': true,
      'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'phone', 'phone': '+919876543210'}),
      'profile.v1': jsonEncode({
        'name': 'Asha',
        'gender': 'female',
        'age': 24,
        'heightCm': 162,
        'weightKg': 58,
        'goal': 'maintain',
        'activity': 'light',
        'diet': 'veg',
        'level': 'beginner',
        'wake': 390,
        'sleep': 1380,
      }),
      'app.firstUse.v1': DateTime(day.year, day.month, day.day - 41).toIso8601String(),
    };
    for (var i = 1; i < 42; i++) {
      final d = day.subtract(Duration(days: i));
      if (i % 9 == 5) continue;
      seed['log.v1.${fmt.format(d)}'] = jsonEncode({
        'workout': i % 4 != 3,
        'water': 2000 + (i * 137) % 700,
        'steps': 6200 + (i * 811) % 5200,
        'meals': 3,
        'protein': 55 + (i * 7) % 30,
      });
    }
    seed['log.v1.${fmt.format(day)}'] = jsonEncode({
      'workout': true,
      'water': 1750,
      'steps': 7420,
      'meals': 2,
      'protein': 48,
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final e in seed.entries) {
      final v = e.value;
      if (v is bool) {
        await prefs.setBool(e.key, v);
      } else {
        await prefs.setString(e.key, v as String);
      }
    }

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
        ],
        child: RepaintBoundary(key: _key, child: const FitTrackerApp()),
      ),
    );
    await settle(6000);
    final router = ProviderScope.containerOf(t.element(find.byType(Navigator).first)).read(routerProvider);

    Future<void> push(String path, [Object? extra]) async {
      router.push(path, extra: extra);
    }

    Future<void> back() async {
      if (router.canPop()) router.pop();
      await settle(600);
    }

    const ring = RingInfo(alarmId: 1, routineId: 'beginner', label: 'Device test alarm');

    // ---- Tabs.
    await visit('01_today', () => router.go(Routes.home));
    await visit('02_workouts', () => router.go(Routes.training));
    await visit('03_myday', () => router.go(Routes.myDay));
    await visit('04_alarms', () => router.go(Routes.alarms));
    await visit('05_diet', () => router.go(Routes.diet));

    // ---- Pages.
    final pages = <(String, String, Object?)>[
      ('10_profile', Routes.profile, null),
      ('11_arc', Routes.arc, null),
      ('12_friends', Routes.friends, null),
      ('13_clubs', Routes.clubs, null),
      ('14_health', Routes.health, null),
      ('15_food_guide', Routes.foodGuide, null),
      ('16_heart_rate', Routes.heartRate, null),
      ('17_watch', Routes.watch, null),
      ('18_steps', Routes.steps, null),
      ('19_water', Routes.water, null),
      ('20_achievements', Routes.achievements, null),
      ('21_weekly_report', Routes.report, null),
      ('22_daily_report', Routes.dailyReport, null),
      ('23_activities', Routes.activities, null),
      ('24_library', Routes.trainingLibrary, null),
      ('25_routine_editor', Routes.routineEditor, null),
      ('26_language', Routes.languageSettings, null),
      ('27_privacy', Routes.privacy, null),
      ('28_walk', Routes.activity, ActivityKind.walk),
      ('29_run', Routes.activity, ActivityKind.run),
      ('30_cycle', Routes.activity, ActivityKind.cycle),
      ('31_skipping', Routes.skipping, null),
      ('32_scan', Routes.scan, MealType.lunch),
      (
        '33_maths_game',
        Routes.challenge,
        const ChallengeArgs(challenge: AlarmChallenge.math, level: ChallengeLevel.easy),
      ),
      (
        '34_memory_game',
        Routes.challenge,
        const ChallengeArgs(challenge: AlarmChallenge.memory, level: ChallengeLevel.easy),
      ),
      (
        '35_order_game',
        Routes.challenge,
        const ChallengeArgs(challenge: AlarmChallenge.order, level: ChallengeLevel.easy),
      ),
    ];
    for (final (name, path, extra) in pages) {
      await visit(name, () => push(path, extra), wait: 3000);
      await back();
    }

    // ---- Camera screens: workout practice and Dance practice.
    await visit(
      '40_workout_camera',
      () => push(Routes.workout, const WorkoutArgs(routineId: 'beginner')),
      scroll: false,
      wait: 14000,
    );
    await back();
    await visit('41_dance_camera', () => push(Routes.dance), scroll: false, wait: 9000);
    await back();

    // ---- An alarm ringing (screen only; the real ringing is the plugin's job).
    await visit('42_ring_workout', () => router.go(Routes.ring, extra: ring), scroll: false);
    await visit(
      '43_ring_dance',
      () => router.go(
        Routes.ring,
        extra: const RingInfo(alarmId: 2, routineId: 'beginner', label: 'Dance alarm', challenge: AlarmChallenge.dance),
      ),
      scroll: false,
    );
    await visit('44_back_home', () => router.go(Routes.home), scroll: false);

    FlutterError.onError = oldOnError;
    File('${out.path}/report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'screens': report, 'errors': errors.length}));
    // Leave the app quietly so timers don't outlive the test.
    await t.pumpWidget(const SizedBox());
    await settle(2000);
  });
}
