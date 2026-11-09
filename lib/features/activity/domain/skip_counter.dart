import 'dart:math' as math;

/// Counts rope skips from the phone's motion sensor (in a pocket or hand).
/// Each jump makes a sharp spike in acceleration; a spike counts when it
/// rises above [threshold] after the signal has settled below [reset], and
/// not sooner than [minGap] after the last one (no one skips faster than
/// about 4 a second).
class SkipCounter {
  SkipCounter({this.threshold = 9, this.reset = 4, this.minGap = const Duration(milliseconds: 220)});

  final double threshold;
  final double reset;
  final Duration minGap;

  int count = 0;
  bool _armed = true;
  DateTime? _last;

  /// Adds one reading of user acceleration (gravity removed), m/s².
  /// Returns true when it counted a skip.
  bool add(double x, double y, double z, DateTime at) {
    final m = math.sqrt(x * x + y * y + z * z);
    if (m < reset) _armed = true;
    if (!_armed || m < threshold) return false;
    if (_last != null && at.difference(_last!) < minGap) return false;
    _armed = false;
    _last = at;
    count++;
    return true;
  }
}
