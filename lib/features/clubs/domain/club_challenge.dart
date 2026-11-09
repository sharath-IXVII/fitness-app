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
  const GpsFix(this.lat, this.lng, this.accuracy, this.at, {this.speed, this.speedAccuracy});

  final double lat;
  final double lng;

  /// Metres.
  final double accuracy;
  final DateTime at;

  /// Speed measured by the GPS chip itself (Doppler), m/s, when the phone
  /// gives one. Much more precise than working it out from positions.
  final double? speed;

  /// m/s; null or 0 when the phone doesn't say.
  final double? speedAccuracy;

  (double, double) get point => (lat, lng);

  bool get hasSpeed => speed != null && speed! >= 0 && (speedAccuracy == null || speedAccuracy! <= 1.5);
}

/// One axis (east or north, in metres) of a constant-velocity Kalman filter.
class _Axis {
  _Axis(this.p);

  double p, v = 0;
  double pp = 0, pv = 0, vv = 4;

  void step(double dt, double accel, double z, double r) {
    // Predict: keep moving at the same speed; uncertainty grows with how
    // sharply someone can speed up or turn.
    p += v * dt;
    final q = accel * accel;
    final dt2 = dt * dt, dt3 = dt2 * dt, dt4 = dt3 * dt;
    pp += dt * (2 * pv + dt * vv) + q * dt4 / 4;
    pv += dt * vv + q * dt3 / 2;
    vv += q * dt2;
    // Update with the reading.
    final s = pp + r;
    final kp = pp / s, kv = pv / s;
    final y = z - p;
    p += kp * y;
    v += kv * y;
    final npp = (1 - kp) * pp, npv = (1 - kp) * pv, nvv = vv - kv * pv;
    pp = npp;
    pv = npv;
    vv = nvv;
  }
}

/// Adds up the distance of a run from GPS readings, as accurately as the
/// phone allows:
///  * readings with poor accuracy are skipped;
///  * a Kalman filter that follows position and speed smooths the readings,
///    so GPS jitter (a few metres of zig-zag on every reading) doesn't pile
///    up into extra distance, while real turns are kept;
///  * nothing is added while standing still;
///  * jumps faster than the activity allows (a car, a glitch) are left out;
///  * the moment the target is reached is worked out between readings, so
///    the finish time isn't rounded up to the next reading.
class RouteTracker {
  RouteTracker(this.kind, {this.maxAccuracy = 25, double? accel, double? step})
    : _accelOverride = accel,
      _stepOverride = step;

  final ActivityKind kind;
  final double maxAccuracy;
  final double? _accelOverride, _stepOverride;

  /// Distance is counted in steps of at least this many metres.
  double get _step => _stepOverride ?? 20;
  double _ae = 0, _an = 0;
  GpsFix? _lastFix;

  /// Smoothed points.
  final List<GpsFix> route = [];

  /// Time from the first reading to each full kilometre, in ms.
  final List<int> splitsMs = [];
  double meters = 0;
  int skipped = 0;

  static const _mPerDegLat = 111320.0;
  late double _lat0, _lng0, _mPerDegLng;
  _Axis? _e, _n;
  DateTime? _t;

  /// The first and latest good reading.
  DateTime? firstAt, lastAt;

  /// Time between the first and last good reading.
  int get spanMs => firstAt == null ? 0 : lastAt!.difference(firstAt!).inMilliseconds;

  /// Current smoothed speed, m/s.
  double get speed => _e == null ? 0 : math.sqrt(_e!.v * _e!.v + _n!.v * _n!.v);

  /// How sharply someone can change speed or direction, m/s².
  double get _accel =>
      _accelOverride ??
      switch (kind) {
        ActivityKind.walk => 0.3,
        ActivityKind.run => 0.5,
        ActivityKind.cycle => 1.0,
      };

  /// Below this smoothed speed, they're standing still.
  double get _still => kind == ActivityKind.cycle ? 0.8 : 0.4;

  (int, DateTime)? _reached;

  /// When [target] metres were reached, if they were.
  DateTime? reachedAt(int target) => _reached?.$1 == target ? _reached!.$2 : null;

  /// Adds [f]; returns true if the distance changed.
  bool add(GpsFix f, {int? target}) {
    if (f.accuracy <= 0 || f.accuracy > maxAccuracy) {
      skipped++;
      return false;
    }
    if (_t != null && !f.at.isAfter(_t!)) return false;
    if (_e == null) {
      _lat0 = f.lat;
      _lng0 = f.lng;
      _mPerDegLng = _mPerDegLat * math.cos(f.lat * math.pi / 180);
      _e = _Axis(0);
      _n = _Axis(0);
      _t = firstAt = lastAt = f.at;
      route.add(GpsFix(f.lat, f.lng, f.accuracy, f.at));
      _lastFix = f;
      return false;
    }
    final dt = f.at.difference(_t!).inMilliseconds / 1000;
    final x = (f.lng - _lng0) * _mPerDegLng, y = (f.lat - _lat0) * _mPerDegLat;
    // A jump no one could make on foot or bike: a glitch, not movement.
    final px = _e!.p + _e!.v * dt, py = _n!.p + _n!.v * dt;
    final jump = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
    if (jump > f.accuracy * 3 + kind.maxKmh / 3.6 * dt) {
      skipped++;
      return false;
    }
    final r = f.accuracy * f.accuracy;
    _e!.step(dt, _accel, x, r);
    _n!.step(dt, _accel, y, r);
    _t = lastAt = f.at;
    final point = GpsFix(_lat0 + _n!.p / _mPerDegLat, _lng0 + _e!.p / _mPerDegLng, f.accuracy, f.at);
    final last = route.last;
    final before = meters;
    double d;
    if (f.hasSpeed && _lastFix?.hasSpeed == true) {
      // The GPS chip's own speed: distance = average speed × time. This
      // follows curves exactly and has no jitter to add up.
      final v = (f.speed! + _lastFix!.speed!) / 2;
      _lastFix = f;
      if (v < _still) return false;
      // Faster than the activity allows (a car, a bus): not counted.
      if (v * 3.6 > kind.maxKmh * 1.3) {
        skipped++;
        return false;
      }
      d = v * dt;
      _ae = _e!.p;
      _an = _n!.p;
    } else {
      _lastFix = f;
      if (speed < _still) return false;
      // No chip speed: count from the last counted point once the smoothed
      // position is a full step away, so leftover jitter can't add up.
      d = math.sqrt((_e!.p - _ae) * (_e!.p - _ae) + (_n!.p - _an) * (_n!.p - _an));
      if (d < _step) return false;
      _ae = _e!.p;
      _an = _n!.p;
    }
    meters += d;
    route.add(point);
    // When a mark (a full km, or the target) was passed, worked out between readings.
    int at(num mark) =>
        (last.at.difference(firstAt!).inMilliseconds + f.at.difference(last.at).inMilliseconds * (mark - before) / d)
            .round();
    while (meters >= (splitsMs.length + 1) * 1000) {
      splitsMs.add(at((splitsMs.length + 1) * 1000));
    }
    if (target != null && before < target && meters >= target && _reached == null && d > 0) {
      _reached = (target, firstAt!.add(Duration(milliseconds: at(target))));
    }
    return true;
  }

  /// How good the signal is, for the screen.
  static String signal(double accuracy) => accuracy <= 10
      ? 'Strong'
      : accuracy <= 20
      ? 'Good'
      : accuracy <= 40
      ? 'Weak'
      : 'Searching';
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
