import 'package:fitalarm/features/steps/domain/step_fusion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first reading sets the baseline; later readings add their delta', () {
    var d = const StepDay();
    d = StepFusion.onSensor(d, 50000, Motion.walking);
    expect(d.sensor, 0);
    d = StepFusion.onSensor(d, 50120, Motion.walking);
    expect(d.sensor, 120);
    expect(d.verified, 120);
  });

  test('steps taken in a vehicle or on a bike are removed', () {
    var d = StepFusion.onSensor(const StepDay(), 1000, Motion.walking);
    d = StepFusion.onSensor(d, 1500, Motion.walking);
    d = StepFusion.onSensor(d, 1800, Motion.vehicle);
    d = StepFusion.onSensor(d, 1900, Motion.cycling);
    d = StepFusion.onSensor(d, 2000, Motion.walking);
    expect(d.sensor, 1000);
    expect(d.removed, 400);
    expect(d.verified, 600);
  });

  test('a reboot (counter drops) counts the new value as fresh steps', () {
    var d = StepFusion.onSensor(const StepDay(), 9000, Motion.walking);
    d = StepFusion.onSensor(d, 9500, Motion.walking);
    d = StepFusion.onSensor(d, 300, Motion.walking);
    expect(d.sensor, 800);
  });

  test('implausible jumps are ignored', () {
    var d = StepFusion.onSensor(const StepDay(), 10, Motion.walking);
    d = StepFusion.onSensor(d, 10 + StepFusion.maxPlausibleDelta + 1, Motion.walking);
    expect(d.sensor, 0);
  });

  test('GPS segments convert distance to steps and ignore vehicle speeds', () {
    var d = StepFusion.onGpsSegment(const StepDay(), meters: 70, speed: 1.4, strideM: 0.7);
    expect(d.gpsSteps, 100);
    d = StepFusion.onGpsSegment(d, meters: 500, speed: 12, strideM: 0.7); // car
    d = StepFusion.onGpsSegment(d, meters: 3, speed: 0.1, strideM: 0.7); // drift
    expect(d.gpsMeters, 70);
    d = StepFusion.onGpsSegment(d, meters: 35, speed: 3, strideM: 0.7); // jogging
    expect(d.gpsSteps, 150);
  });

  test('haversine distance', () {
    // ~111 km per degree of latitude.
    expect(StepFusion.distance(12.0, 76.0, 13.0, 76.0), closeTo(111195, 200));
    expect(StepFusion.distance(12.3, 76.6, 12.3, 76.6), 0);
  });

  test('json round-trip', () {
    const d = StepDay(sensor: 5, removed: 1, gpsMeters: 12.5, gpsSteps: 18, lastCumulative: 99);
    expect(StepDay.fromJson(d.toJson()).toJson(), d.toJson());
  });

  group('merging GPS with the step sensor', () {
    test('sensor only: steps and distance come from the sensor', () {
      var d = StepFusion.onSensor(const StepDay(), 0, Motion.walking);
      d = StepFusion.onSensor(d, 1000, Motion.walking);
      expect(d.total, 1000);
      expect(d.distanceMeters(0.7), closeTo(700, 0.01));
    });

    test('while GPS tracks, the higher count wins and nothing is counted twice', () {
      var d = StepFusion.onSensor(const StepDay(), 0, Motion.walking);
      d = StepFusion.onSensor(d, 2000, Motion.walking); // 2,000 without GPS
      d = StepFusion.onSensor(d, 2500, Motion.walking, gpsTracking: true); // 500 with GPS on
      // GPS measured 560 m = 800 steps at 0.7 m: the sensor missed 300.
      d = StepFusion.onGpsSegment(d, meters: 560, speed: 1.4, strideM: 0.7);
      expect(d.sensorWhileGps, 500);
      expect(d.total, 2800);
      expect(d.distanceMeters(0.7), closeTo(2000 * 0.7 + 560, 0.01));

      // If the sensor saw more than GPS, the sensor count stands.
      var e = StepFusion.onSensor(const StepDay(), 0, Motion.walking);
      e = StepFusion.onSensor(e, 900, Motion.walking, gpsTracking: true);
      e = StepFusion.onGpsSegment(e, meters: 350, speed: 1.4, strideM: 0.7); // 500 steps
      expect(e.total, 900);
      expect(e.distanceMeters(0.7), closeTo(900 * 0.7, 0.01));
    });

    test('vehicle speed seen by GPS removes the bumps the sensor counted', () {
      var d = StepFusion.onSensor(const StepDay(), 0, Motion.unknown);
      d = StepFusion.onSensor(d, 300, Motion.unknown, gpsTracking: true, gpsVehicle: true);
      expect(d.total, 0);
      expect(StepFusion.isVehicleSpeed(12), isTrue);
      expect(StepFusion.isVehicleSpeed(1.5), isFalse);
      // Driving segments add no distance or steps.
      d = StepFusion.onGpsSegment(d, meters: 500, speed: 12, strideM: 0.7);
      expect(d.gpsMeters, 0);
    });

    test('the merged day survives a restart', () {
      final d = const StepDay(sensor: 10, gpsMeters: 5, gpsSteps: 7, sensorWhileGps: 3, lastCumulative: 42);
      final back = StepDay.fromJson(d.toJson());
      expect(back.sensorWhileGps, 3);
      expect(back.total, d.total);
    });
  });

  test('Android\'s background record counts steps taken while the app was closed', () {
    // App opened at noon: the live sensor saw nothing yet, Android recorded 6,000.
    var d = StepFusion.onSensor(const StepDay(), 50000, Motion.walking).copyWith(recorded: 6000);
    expect(d.total, 6000);
    expect(d.distanceMeters(0.7), closeTo(4200, 0.01));
    // Live counting takes over once it's ahead; nothing counted twice.
    d = StepFusion.onSensor(d, 57000, Motion.walking);
    expect(d.total, 7000);
  });

  test('motion-sensor steps merge by taking the highest view, never adding', () {
    var d = StepFusion.onSensor(const StepDay(), 0, Motion.walking);
    d = StepFusion.onSensor(d, 1000, Motion.walking);
    expect(d.copyWith(motionSteps: 900).total, 1000); // the step counter saw more
    expect(d.copyWith(motionSteps: 1100).total, 1100); // the accelerometer saw more
    // Distance follows the same steps.
    expect(d.copyWith(motionSteps: 1100).distanceMeters(0.7), closeTo(1100 * 0.7, 0.01));
    // And it survives being saved.
    expect(StepDay.fromJson(d.copyWith(motionSteps: 1100).toJson()).motionSteps, 1100);
  });
}
