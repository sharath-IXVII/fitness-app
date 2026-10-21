import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage.dart';
import 'features/alarm/alarm_scheduler.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship inside the app (assets/google_fonts) so text never flickers
  // or depends on the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Inter']) {
      final license = await rootBundle.loadString('assets/google_fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  await AlarmScheduler.init();
  final prefs = await SharedPreferences.getInstance();
  final auth = await _authService(prefs);
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs), authServiceProvider.overrideWithValue(auth)],
      child: const FitAlarmApp(),
    ),
  );
}

/// Real Firebase sign-in when the app has been connected to a Firebase
/// project (google-services.json / GoogleService-Info.plist present);
/// otherwise a clearly labelled demo mode.
Future<AuthService> _authService(SharedPreferences prefs) async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp();
      return FirebaseAuthService();
    } catch (e) {
      debugPrint('Firebase not configured, using demo sign-in: $e');
    }
  }
  return DemoAuthService(prefs);
}
