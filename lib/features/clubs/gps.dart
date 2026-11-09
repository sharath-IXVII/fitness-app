import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'domain/club_challenge.dart';

/// Why location can't be used, in plain words; null when it's ready.
typedef LocationCheck = Future<String?> Function();

/// The phone's GPS for club challenges. Overridden in tests.
class Gps {
  const Gps();

  /// Asks for location if needed.
  Future<String?> ensure() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on Location (GPS) in your phone settings, then try again.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return 'Allow location so FittArc can measure your route.';
      if (p == LocationPermission.deniedForever) {
        return 'Location is blocked for FittArc. Allow it in Settings → Apps → FittArc → Permissions.';
      }
      // "Approximate" location is off by hundreds of metres: useless for a route.
      if (await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced) {
        return 'Turn on "Precise location" for FittArc so your distance is measured accurately.';
      }
      return null;
    } catch (e) {
      debugPrint('location check failed: $e');
      return "Couldn't use location on this phone.";
    }
  }

  Future<GpsFix?> current() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
      );
      return GpsFix(p.latitude, p.longitude, p.accuracy, p.timestamp);
    } catch (_) {
      return null;
    }
  }

  /// Readings while the challenge runs. On Android a notification keeps
  /// tracking going when the screen is off.
  Stream<GpsFix> track() {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
            intervalDuration: const Duration(seconds: 2),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'FittArc challenge running',
              notificationText: 'Measuring your route. Open FittArc to see your progress.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5);
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((p) => GpsFix(p.latitude, p.longitude, p.accuracy, p.timestamp));
  }
}

final gpsProvider = Provider<Gps>((ref) => const Gps());
