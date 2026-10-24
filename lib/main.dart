import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/reminders.dart';
import 'core/storage.dart';
import 'features/alarm/alarm_scheduler.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  runZonedGuarded(_start, (e, st) {
    debugPrint('Uncaught: $e\n$st');
    _lastError ??= '$e';
  });
}

String? _lastError;

/// Runs a startup step without letting a failure (or a hang) keep the app
/// from opening. Problems are remembered and shown on screen.
Future<T?> _safe<T>(String name, Future<T> Function() step) async {
  try {
    return await step().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('Startup step "$name" failed: $e\n$st');
    _lastError ??= '$name: $e';
    return null;
  }
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In release builds a broken widget would otherwise be an empty grey box;
  // show what went wrong so it can be reported.
  ErrorWidget.builder = (details) => _ErrorView(message: details.exceptionAsString());
  // Fonts ship inside the app (assets/google_fonts) so text never flickers
  // or depends on the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Inter', 'ChakraPetch']) {
      final license = await rootBundle.loadString('assets/google_fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  await _safe('orientation', () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await _safe('alarms', AlarmScheduler.init);
  await _safe('reminders', Reminders.init);
  final prefs = await _safe('storage', SharedPreferences.getInstance);
  if (prefs == null) {
    runApp(_ErrorView(message: _lastError ?? 'Storage unavailable'));
    return;
  }
  final auth = await _safe('sign-in', () => _authService(prefs)) ?? DemoAuthService(prefs);
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs), authServiceProvider.overrideWithValue(auth)],
      child: const FitTrackerApp(),
    ),
  );
}

/// Real Firebase sign-in when the app has been connected to a Firebase
/// project (google-services.json / GoogleService-Info.plist present);
/// otherwise a clearly labelled demo mode.
Future<AuthService> _authService(SharedPreferences prefs) async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      return FirebaseAuthService();
    } catch (e) {
      debugPrint('Firebase not configured, using demo sign-in: $e');
    }
  }
  return DemoAuthService(prefs);
}

/// Shown instead of a blank screen if something fails badly, so the user can
/// send a screenshot.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xFFFAF6EF),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Text(
              'Something went wrong. Please send a screenshot of this screen.\n\n$message',
              style: const TextStyle(
                color: Color(0xFF3A2E25),
                fontSize: 14,
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
