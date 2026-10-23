import 'dart:math' as math;

/// What the phone thinks the user is doing (from activity recognition).
enum Motion { still, walking, running, cycling, vehicle, unknown }

/// One day's step bookkeeping. Everything needed to resume after the app
/// restarts or the phone reboots is persisted.
class StepDay {
  const StepDay({
    this.sensor = 0,
    this.removed = 0,
    this.gpsMeters = 0,
    this.gpsSteps = 0,
    this.sensorWhileGps = 0,
    this.lastCumulative,
  });

  /// Steps the hardware counter recorded today.
  final int sensor;

  /// Steps recorded while riding a bike or in a vehicle — not counted.
  final int removed;

  /// Distance walked/run while GPS was tracking, and that distance as steps.
  final double gpsMeters;
  final int gpsSteps;

  /// Sensor steps (on foot) taken while GPS was tracking, so the two
  /// sources can be merged without counting the same steps twice.
  final int sensorWhileGps;

  /// Last raw reading of the since-boot counter, to compute deltas.
  final int? lastCumulative;

  /// Sensor steps minus those taken in a vehicle.
  int get verified => math.max(0, sensor - removed);

  /// Today's steps. While GPS was tracking, the higher of the two sources
  /// counts (GPS fills in steps the sensor missed); otherwise the sensor.
  int get total => verified + math.max(0, gpsSteps - sensorWhileGps);

  /// Today's distance: GPS where it was tracking, steps × stride elsewhere.
  double distanceMeters(double strideM) =>
      math.max(gpsMeters, sensorWhileGps * strideM) + math.max(0, verified - sensorWhileGps) * strideM;

  StepDay copyWith({
    int? sensor,
    int? removed,
    double? gpsMeters,
    int? gpsSteps,
    int? sensorWhileGps,
    int? lastCumulative,
  }) => StepDay(
    sensor: sensor ?? this.sensor,
    removed: removed ?? this.removed,
    gpsMeters: gpsMeters ?? this.gpsMeters,
    gpsSteps: gpsSteps ?? this.gpsSteps,
    sensorWhileGps: sensorWhileGps ?? this.sensorWhileGps,
    lastCumulative: lastCumulative ?? this.lastCumulative,
  );

  Map<String, dynamic> toJson() => {
    'sensor': sensor,
    'removed': removed,
    'gpsM': gpsMeters,
    'gpsSteps': gpsSteps,
    'sensorGps': sensorWhileGps,
    'last': ?lastCumulative,
  };

  factory StepDay.fromJson(Map<String, dynamic> j) => StepDay(
    sensor: j['sensor'] as int? ?? 0,
    removed: j['removed'] as int? ?? 0,
    gpsMeters: (j['gpsM'] as num?)?.toDouble() ?? 0,
    gpsSteps: j['gpsSteps'] as int? ?? 0,
    sensorWhileGps: j['sensorGps'] as int? ?? 0,
    lastCumulative: j['last'] as int?,
  );
}

/// Pure step-fusion rules, independent of plugins so they can be tested.
abstract final class StepFusion {
  /// The hardware counter's job is to count steps; a jump bigger than this
  /// between two readings is treated as a reset artefact, not walking.
  static const maxPlausibleDelta = 20000;

  /// Applies a new reading of the since-boot step counter.
  ///
  /// The counter resets to 0 on reboot; a reading lower than the last one
  /// means a reboot, and the new value itself is the steps since then.
  ///
  /// [gpsTracking]: GPS is running, so on-foot steps are also tallied for
  /// merging. [gpsVehicle]: GPS saw vehicle speed, so the steps are bumps.
  static StepDay onSensor(
    StepDay day,
    int cumulative,
    Motion motion, {
    bool gpsTracking = false,
    bool gpsVehicle = false,
  }) {
    final last = day.lastCumulative;
    final int delta;
    if (last == null) {
      delta = 0; // first reading today: establish the baseline
    } else if (cumulative < last) {
      delta = cumulative; // reboot
    } else {
      delta = cumulative - last;
    }
    if (delta <= 0 || delta > maxPlausibleDelta) return day.copyWith(lastCumulative: cumulative);
    final inVehicle = gpsVehicle || motion == Motion.vehicle || motion == Motion.cycling;
    return day.copyWith(
      sensor: day.sensor + delta,
      removed: inVehicle ? day.removed + delta : day.removed,
      sensorWhileGps: gpsTracking && !inVehicle ? day.sensorWhileGps + delta : day.sensorWhileGps,
      lastCumulative: cumulative,
    );
  }

  /// Fastest speed that still counts as walking or running (≈ 14 km/h).
  static const maxFootSpeed = 3.9;
  static const minFootSpeed = 0.4;

  /// Worst GPS accuracy (metres) a point may have to be used.
  static const maxAccuracy = 25.0;

  /// Whether GPS speed says the user is in a vehicle or on a bike.
  static bool isVehicleSpeed(double speed) => speed > maxFootSpeed;

  /// Adds a GPS segment of [meters] covered at [speed] m/s, converting it to
  /// steps with the user's [strideM]. Segments too fast (bike, car) or too
  /// slow (GPS drift while standing) are ignored.
  static StepDay onGpsSegment(StepDay day, {required double meters, required double speed, required double strideM}) {
    if (speed < minFootSpeed || speed > maxFootSpeed || meters <= 0 || strideM <= 0) return day;
    final total = day.gpsMeters + meters;
    return day.copyWith(gpsMeters: total, gpsSteps: (total / strideM).round());
  }

  /// Distance between two coordinates in metres (haversine).
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }
}
