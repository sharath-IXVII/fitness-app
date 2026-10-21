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
}
