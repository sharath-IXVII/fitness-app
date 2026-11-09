import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// What a club challenge is done on foot or by bike.
enum ActivityKind {
  run('Run', Icons.directions_run_rounded, 25, 60),
  walk('Walk', Icons.directions_walk_rounded, 9, 25),
  cycle('Cycle', Icons.directions_bike_rounded, 60, 25);

  const ActivityKind(this.label, this.icon, this.maxKmh, this.kcalPerKm);

  final String label;
  final IconData icon;

  /// Faster than this on average is not believable, so it doesn't count.
  final double maxKmh;

  /// Rough calories for an average adult, for the summary.
  final double kcalPerKm;

  /// The shortest time [meters] can honestly take.
  int minMillis(int meters) => (meters / 1000 / maxKmh * 3600 * 1000).round();
}

/// A challenge the club admin sets, e.g. "Run 8 km from the lake gate".
class ClubChallenge {
  const ClubChallenge({
    required this.id,
    required this.clubId,
    required this.title,
    required this.kind,
    required this.distanceM,
    required this.startsAt,
    required this.endsAt,
    this.start,
    this.startName = '',
  });

  /// How close to the start point a member must be to begin.
  static const startRadiusM = 300.0;

  final String id;
  final String clubId;
  final String title;
  final ActivityKind kind;
  final int distanceM;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Where it starts (latitude, longitude), or null to start anywhere.
  final (double, double)? start;

  /// "Lake gate", shown to members.
  final String startName;

  bool openAt(DateTime t) => !t.isBefore(startsAt) && t.isBefore(endsAt);

  String get distanceLabel => formatKm(distanceM);

  /// XP for finishing: 50, plus 10 per km.
  int get finishXp => 50 + (distanceM / 100).round();
}

/// One member's best finish.
class ChallengeResult {
  const ChallengeResult({required this.uid, required this.name, required this.timeMs, required this.distanceM});

  final String uid;
  final String name;
  final int timeMs;
  final int distanceM;
}

String formatKm(num meters) {
  final km = meters / 1000;
  return km == km.roundToDouble() ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
}

String formatDuration(int ms) {
  final s = ms ~/ 1000;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

/// "5:32 /km".
String formatPace(int ms, num meters) {
  if (meters <= 0) return '–';
  final perKm = (ms / (meters / 1000)).round();
  return '${formatDuration(perKm)} /km';
}

/// Metres between two points on Earth.
double distanceBetween((double, double) a, (double, double) b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.$1 - a.$1), dLng = rad(b.$2 - a.$2);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(a.$1)) * math.cos(rad(b.$1)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// One GPS reading.
class GpsFix {
  const GpsFix(this.lat, this.lng, this.accuracy, this.at);

  final double lat;
  final double lng;

  /// Metres.
  final double accuracy;
  final DateTime at;

  (double, double) get point => (lat, lng);
}

/// Adds up the distance of a run from GPS readings. Poor readings and jumps
/// faster than the activity allows (a car, a GPS glitch) are left out.
class RouteTracker {
  RouteTracker(this.kind, {this.maxAccuracy = 30});

  final ActivityKind kind;
  final double maxAccuracy;

  final List<GpsFix> route = [];
  double meters = 0;
  int skipped = 0;

  /// Time between the first and last counted reading.
  int get spanMs => route.length < 2 ? 0 : route.last.at.difference(route.first.at).inMilliseconds;

  /// Adds [f]; returns true if it counted.
  bool add(GpsFix f) {
    if (f.accuracy > maxAccuracy) {
      skipped++;
      return false;
    }
    if (route.isEmpty) {
      route.add(f);
      return true;
    }
    final last = route.last;
    final secs = f.at.difference(last.at).inMilliseconds / 1000;
    if (secs <= 0) return false;
    final d = distanceBetween(last.point, f.point);
    // Tiny moves are GPS wobble while standing still.
    if (d < 3) return false;
    // Faster than the activity allows (with headroom for a sprint): ignore.
    if (d / secs * 3.6 > kind.maxKmh * 1.6) {
      skipped++;
      return false;
    }
    meters += d;
    route.add(f);
    return true;
  }
}

/// Reads a challenge document; null when it's damaged.
ClubChallenge? challengeFromJson(String club, String id, Map<String, dynamic> j) {
  try {
    final start = j['start'];
    return ClubChallenge(
      id: id,
      clubId: club,
      title: j['title'] as String,
      kind: ActivityKind.values.asNameMap()[j['kind']] ?? ActivityKind.run,
      distanceM: (j['distanceM'] as num).toInt(),
      startsAt: (j['startsAt'] as Timestamp).toDate(),
      endsAt: (j['endsAt'] as Timestamp).toDate(),
      start: start is GeoPoint ? (start.latitude, start.longitude) : null,
      startName: j['startName'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}
