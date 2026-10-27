// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the app's own screens as PNGs for the Play Store listing.
//   flutter test tool/store_shots/render_test.dart
// Output goes to the folder in the SHOTS_DIR environment variable.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/router.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/health/watch_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Watch implements WatchData {
  @override
  Future<WatchStatus> status() async => WatchStatus.ready;

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<void> install() async {}

  @override
  Future<WatchSnapshot> read(DateTime now) async =>
      WatchSnapshot(steps: 6240, latestBpm: 71, latestBpmAt: now, restingBpm: 58, sleepMinutes: 425);
}

Future<void> _wait(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// (name, logical size, pixel ratio) for each Play slot.
const _variants = [
  ('phone', Size(360, 640), 3.0), // 1080 x 1920
  ('tablet7', Size(600, 1066.6667), 1.8), // 1080 x 1920
  ('tablet10', Size(800, 1422.2222), 1.8), // 1440 x 2560
];

/// Loads the icon font and the default text font from the Flutter SDK, which
/// widget tests leave out, so the pictures show real icons and letters.
Future<void> _loadSdkFonts() async {
  final sdk = Platform.environment['FLUTTER_SDK_FONTS'] ?? '';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.view(File('$sdk/$f').readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  // Text with no font named falls back to the test font; use Inter for it.
  final inter = FontLoader('FlutterTest');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(Future.value(ByteData.view(File('assets/google_fonts/Inter-$f.ttf').readAsBytesSync().buffer)));
  }
  await inter.load();
  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadSdkFonts();
  });
  final out = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/store_shots')..createSync(recursive: true);

  for (final (variant, size, ratio) in _variants) {
    testWidgets('store screenshots: $variant', (t) async {
      t.view.physicalSize = size * ratio;
      t.view.devicePixelRatio = ratio;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({
        'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'google', 'name': 'Sharath'}),
        'guide.health.v1': true,
        'guide.alarm.v1': true,
        'health.arc.v1': jsonEncode({
          for (var i = 0; i < 5; i++)
            '2026-10-${(27 - i).toString().padLeft(2, '0')}': [18.0, 22.5, 0.0, 14.0, 31.0][i],
        }),
        'profile.v1': jsonEncode({
          'name': 'Sharath',
          'gender': 'male',
          'age': 24,
          'heightCm': 170,
          'weightKg': 65,
          'goal': 'loseWeight',
          'activity': 'light',
          'diet': 'veg',
          'level': 'beginner',
          'wake': 360,
          'sleep': 1380,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      // The sound player has no phone to talk to here.
      for (final c in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers.global/events', 'xyz.luan/audioplayers']) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          MethodChannel(c),
          (_) async => null,
        );
      }
      final key = GlobalKey();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
            watchDataProvider.overrideWithValue(_Watch()),
          ],
          child: RepaintBoundary(key: key, child: const FitTrackerApp()),
        ),
      );
      await _wait(t, 5600);

      Future<void> shot(String name) async {
        await _wait(t, 1500);
        await t.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: ratio);
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          File('${out.path}/$variant-$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
        });
      }

      GoRouter router() => GoRouter.of(t.element(find.byType(Scaffold).first));

      await shot('1-today');
      router().go(Routes.alarms);
      await shot('2-alarms');
      await t.tap(find.text('Add alarm').first);
      await _wait(t, 900);
      await shot('3-alarm-editor');
      await t.tap(find.text('Save alarm'));
      await _wait(t, 900);
      t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).hideCurrentSnackBar();
      await _wait(t, 600);
      await shot('2b-alarm-set');
      router().go(Routes.training);
      await shot('4-workouts');
      router().push(Routes.arc);
      await shot('5-arc');
      router().pop();
      router().push(Routes.health);
      await shot('6-health');
      router().push(Routes.watch);
      await shot('7-watch');
      router().pop();
      router().pop();
      router().go(Routes.diet);
      await shot('8-diet');
      // The sound player has no phone to talk to here; its complaints are expected.
      while (t.takeException() != null) {}
    });
  }
}
