import 'dart:math' as math;

/// Counts steps from the accelerometer, with the gyroscope used to reject
/// shaking. Pure maths so it can be tested without a phone.
///
/// The acceleration magnitude is smoothed and compared with its own slow
/// average (which follows gravity, whatever way the phone is held). Each
/// upward crossing of [threshold] is a step candidate. A walking rhythm must
/// be seen ([warmup] candidates in a row, each within [maxInterval]) before
/// steps count, which keeps fidgeting from being counted; the warm-up steps
/// are then added back.
class StepDetector {
  StepDetector({
    this.threshold = 1.3,
    this.minInterval = const Duration(milliseconds: 280),
    this.maxInterval = const Duration(milliseconds: 1300),
    this.maxRotation = 7.0,
    this.warmup = 4,
  });

  /// How far above the slow average a step peak must rise (m/s²).
  final double threshold;
  final Duration minInterval;
  final Duration maxInterval;

  /// Turning faster than this (rad/s) is a shake or a swing, not a step.
  final double maxRotation;
  final int warmup;

  double _baseline = 9.81;
  double _smooth = 0;
  bool _above = false;
  int? _lastStepMs;
  int _streak = 0;
  double _rotation = 0;
  bool _seeded = false;

  /// Latest gyroscope reading, as an angular speed in rad/s.
  void onGyro(double x, double y, double z) => _rotation = math.sqrt(x * x + y * y + z * z);

  /// Feeds one accelerometer sample taken at [ms] (milliseconds). Returns how
  /// many steps to add: 0 normally, [warmup] when a rhythm is first
  /// confirmed, 1 for each step after that.
  int onAccel(int ms, double x, double y, double z) {
    final m = math.sqrt(x * x + y * y + z * z);
    if (!_seeded) {
      _baseline = m;
      _seeded = true;
    }
    _baseline += 0.02 * (m - _baseline);
    _smooth += 0.35 * ((m - _baseline) - _smooth);

    if (_smooth > threshold) {
      if (_above) return 0;
      _above = true;
      final last = _lastStepMs;
      if (last != null && ms - last < minInterval.inMilliseconds) return 0;
      if (_rotation > maxRotation) return 0;
      if (last == null || ms - last > maxInterval.inMilliseconds) _streak = 0;
      _lastStepMs = ms;
      _streak++;
      if (_streak < warmup) return 0;
      return _streak == warmup ? warmup : 1;
    }
    if (_smooth < threshold * 0.4) _above = false;
    return 0;
  }

  /// Forgets the rhythm (after a pause, or when walking stops being plausible).
  void reset() {
    _streak = 0;
    _lastStepMs = null;
    _above = false;
  }
}
