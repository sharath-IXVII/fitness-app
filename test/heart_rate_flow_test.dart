import 'dart:convert';
import 'dart:math' as math;

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/health/domain/pulse_signal.dart';
import 'package:fitalarm/features/health/health_screen.dart';
import 'package:fitalarm/features/health/pulse_source.dart';
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

/// A pretend fingertip: 32 seconds of a steady 72 bpm signal, or a finger
/// that is never placed on the camera.
class _FakeSource implements PulseSource {
  _FakeSource({this.fingerOn = true, this.fail});

  final bool fingerOn;
  final String? fail;
  bool stopped = false;

  @override
  Stream<PulseSample> start() async* {
    if (fail != null) throw fail!;
    final rnd = math.Random(2);
    for (var i = 0; i < 32 * 30; i++) {
      final tt = i / 30;
      final wave = math.sin(2 * math.pi * 1.2 * tt) + 0.35 * math.sin(4 * math.pi * 1.2 * tt + 0.8);
      yield PulseSample((tt * 1e6).round(), 120 + wave + (rnd.nextDouble() - 0.5) * 0.3, fingerOn: fingerOn);
      if (i % 30 == 0) await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> stop() async => stopped = true;
}

Future<SharedPreferences> _open(WidgetTester t, PulseSource source) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'google', 'name': 'Asha'}),
    'guide.health.v1': true,
    'profile.v1': jsonEncode({
      'name': 'Asha',
      'gender': 'female',
      'age': 24,
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
        pulseSourceProvider.overrideWithValue(source),
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
  return prefs;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('heart rate: measure with the camera, see the result, save it', (t) async {
    final source = _FakeSource();
    final prefs = await _open(t, source);
    await t.tap(find.text('Measure heart rate'));
    await _wait(t);
    expect(find.text('Measure your pulse in 30 seconds'), findsOneWidget);
    expect(find.textContaining('estimate from the camera'), findsOneWidget);

    await t.tap(find.text('Start'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await _wait(t, 500);

    // The result is close to 72 and is judged as a resting pulse.
    final shown = find.byWidgetPredicate((w) => w is Text && RegExp(r'^(7[0-4])$').hasMatch(w.data ?? ''));
    expect(shown, findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(source.stopped, isTrue, reason: 'the camera and flash are switched off at the end');

    await t.tap(find.text('Save to my readings'));
    await _wait(t, 300);
    final saved = jsonDecode(prefs.getString('health.readings.v1')!) as List;
    expect(saved.single['k'], 'pulse');
    expect(saved.single['v'], inInclusiveRange(70, 74));
  });

  testWidgets('heart rate: no finger means no number, and a camera problem is explained', (t) async {
    await _open(t, _FakeSource(fingerOn: false));
    await t.tap(find.text('Measure heart rate'));
    await _wait(t);
    await t.tap(find.text('Start'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _wait(t, 300);
    expect(find.text('Cover the camera and the flash with your fingertip'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('heart rate: a camera that will not start shows a clear message', (t) async {
    await _open(
      t,
      _FakeSource(fail: 'Camera permission is off. Allow the camera for FittArc in Settings and try again.'),
    );
    await t.tap(find.text('Measure heart rate'));
    await _wait(t);
    await t.tap(find.text('Start'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await _wait(t, 300);
    expect(find.text('Could not start'), findsOneWidget);
    expect(find.textContaining('Camera permission is off'), findsOneWidget);
  });

  testWidgets('height and weight: shows BMI, saves new numbers, and refuses impossible ones', (t) async {
    final prefs = await _open(t, _FakeSource());
    final page = find.descendant(of: find.byType(HealthScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Height and weight'), 200, scrollable: page);
    expect(find.text('162 cm'), findsOneWidget);
    expect(find.text('64 kg'), findsOneWidget);
    expect(find.text('24.4'), findsOneWidget); // 64 / 1.62^2
    expect(find.text('Overweight'), findsOneWidget);

    // Bring the card clear of the bottom bar before tapping.
    await t.scrollUntilVisible(find.text('Update'), 200, scrollable: page);
    await t.drag(page, const Offset(0, -250));
    await _wait(t, 300);
    await t.tap(find.text('Update'));
    await _wait(t);
    await t.enterText(find.byType(TextField).at(0), '400');
    await t.tap(find.text('Save'));
    await _wait(t, 300);
    expect(find.textContaining('Height should be between'), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), '170');
    await t.enterText(find.byType(TextField).at(1), '62');
    await t.tap(find.text('Save'));
    await _wait(t);
    expect(find.text('170 cm'), findsOneWidget);
    expect(find.text('62 kg'), findsOneWidget);
    expect(find.text('21.5'), findsOneWidget);
    expect(find.text('Healthy range'), findsOneWidget);
    final profile = jsonDecode(prefs.getString('profile.v1')!) as Map<String, dynamic>;
    expect(profile['heightCm'], 170);
    expect(profile['weightKg'], 62);
  });
}
