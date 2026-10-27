import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/health/domain/live_hr.dart';
import 'package:fitalarm/features/health/health_screen.dart';
import 'package:fitalarm/features/health/hr_source.dart';
import 'package:fitalarm/features/health/watch_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _wait(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A pretend watch that the test sends heart-rate readings through.
class _FakeHr implements HrSource {
  _FakeHr({this.scanError});

  final String? scanError;
  final readings = StreamController<HrMeasurement>();
  bool disconnected = false;

  @override
  Stream<List<HrDevice>> scan() async* {
    if (scanError != null) throw StateError(scanError!);
    yield const [HrDevice(id: 'AA:BB', name: 'Pretend Watch', rssi: -50)];
  }

  @override
  Future<void> stopScan() async {}

  @override
  Stream<HrMeasurement> connect(String id) => readings.stream;

  @override
  Future<void> disconnect() async => disconnected = true;
}

class _FakeWatch implements WatchData {
  _FakeWatch(this._status, {this.snapshot = const WatchSnapshot()});

  WatchStatus _status;
  final WatchSnapshot snapshot;
  bool asked = false;

  @override
  Future<WatchStatus> status() async => _status;

  @override
  Future<bool> requestAccess() async {
    asked = true;
    _status = WatchStatus.ready;
    return true;
  }

  @override
  Future<void> install() async {}

  @override
  Future<WatchSnapshot> read(DateTime now) async => snapshot;
}

Future<SharedPreferences> _open(WidgetTester t, {required HrSource hr, required WatchData watch}) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'google', 'name': 'Asha'}),
    'guide.health.v1': true,
    'profile.v1': jsonEncode({
      'name': 'Asha',
      'gender': 'female',
      'age': 40,
      'heightCm': 162,
      'weightKg': 64,
      'goal': 'loseWeight',
      'activity': 'light',
      'diet': 'veg',
      'level': 'beginner',
      'wake': 390,
      'sleep': 1380,
    }),
  });
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
        hrSourceProvider.overrideWithValue(hr),
        watchDataProvider.overrideWithValue(watch),
      ],
      child: const FitTrackerApp(),
    ),
  );
  await _wait(t, 5600);
  final today = find.byType(Scrollable).hitTestable().first;
  await t.scrollUntilVisible(find.text('Health check'), 200, scrollable: today);
  await t.drag(today, const Offset(0, -240));
  await _wait(t, 300);
  await t.tap(find.text('Health check'));
  await _wait(t);
  final list = find.descendant(of: find.byType(HealthScreen), matching: find.byType(Scrollable)).first;
  await t.scrollUntilVisible(find.text('Connect your watch'), 200, scrollable: list);
  await t.tap(find.text('Connect your watch'));
  await _wait(t);
  return prefs;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('watch: live heart rate shows the zone and the session turns into Arc minutes', (t) async {
    final hr = _FakeHr();
    var now = DateTime(2026, 10, 27, 7);
    await withClock(Clock(() => now), () async {
      final prefs = await _open(t, hr: hr, watch: _FakeWatch(WatchStatus.notAllowed));
      expect(find.text('Arc minutes this week'), findsOneWidget);
      await t.tap(find.text('Live heart rate'));
      await _wait(t);
      expect(find.text('Pretend Watch'), findsOneWidget);
      expect(find.textContaining('Not every watch can share'), findsOneWidget);

      await t.tap(find.text('Pretend Watch'));
      await _wait(t, 300);
      // Age 40 gives a top rate of 180. 140 bpm is "Pushing" (hard, counts double).
      for (var i = 0; i < 61; i++) {
        hr.readings.add(const HrMeasurement(140));
        await t.pump();
        now = now.add(const Duration(seconds: 1));
      }
      await _wait(t, 300);
      expect(find.text('140'), findsNWidgets(2)); // the big number and "Highest"
      expect(find.text('Pushing'), findsOneWidget);

      await t.tap(find.text('Finish'));
      await _wait(t, 600);
      expect(find.text('Arc minutes earned'), findsOneWidget);
      expect(hr.disconnected, isTrue);
      final saved = jsonDecode(prefs.getString('health.arc.v1')!) as Map<String, dynamic>;
      expect(saved['2026-10-27'], closeTo(2.0, 0.05)); // 60 s hard = 2 Arc minutes
    });
  });

  testWidgets('watch: a lost sensor shows a hint instead of a number', (t) async {
    final hr = _FakeHr();
    await withClock(Clock(() => DateTime(2026, 10, 27, 7)), () async {
      await _open(t, hr: hr, watch: _FakeWatch(WatchStatus.notAllowed));
      await t.tap(find.text('Live heart rate'));
      await _wait(t);
      await t.tap(find.text('Pretend Watch'));
      await _wait(t, 300);
      hr.readings.add(const HrMeasurement(0, contactLost: true));
      await t.pump();
      await _wait(t, 300);
      expect(find.text('Wear the sensor snugly'), findsOneWidget);
    });
  });

  testWidgets('watch: Bluetooth off is explained', (t) async {
    await _open(
      t,
      hr: _FakeHr(scanError: 'Bluetooth is off. Turn it on and try again.'),
      watch: _FakeWatch(WatchStatus.unavailable),
    );
    await t.tap(find.text('Live heart rate'));
    await _wait(t);
    expect(find.text('Could not connect'), findsOneWidget);
    expect(find.text('Bluetooth is off. Turn it on and try again.'), findsOneWidget);
  });

  testWidgets('watch: Health Connect asks first, then shows steps, heart rate and sleep', (t) async {
    final watch = _FakeWatch(
      WatchStatus.notAllowed,
      snapshot: WatchSnapshot(
        steps: 6240,
        latestBpm: 71,
        latestBpmAt: DateTime(2026, 10, 27, 6, 40),
        restingBpm: 58,
        sleepMinutes: 425,
      ),
    );
    await _open(t, hr: _FakeHr(), watch: watch);
    expect(find.text('Allow FittArc to read'), findsOneWidget);
    await t.tap(find.text('Allow FittArc to read'));
    await _wait(t);
    expect(watch.asked, isTrue);
    expect(find.text('6,240'), findsOneWidget);
    expect(find.text('71'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.text('7 h 5 min'), findsOneWidget);
  });

  testWidgets('watch: without Health Connect the page says so and Bluetooth still works', (t) async {
    await _open(t, hr: _FakeHr(), watch: _FakeWatch(WatchStatus.unavailable));
    expect(find.textContaining('Health Connect is not available'), findsOneWidget);
    expect(find.text('Live heart rate'), findsOneWidget);
  });
}
