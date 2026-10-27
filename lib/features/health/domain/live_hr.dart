/// Live heart rate from a Bluetooth watch or chest strap, and the "Arc
/// minutes" that a session earns.
///
/// Nothing here touches Bluetooth, so it is all easy to test.
library;

/// One notification from the standard Bluetooth Heart Rate Measurement
/// characteristic (0x2A37).
class HrMeasurement {
  const HrMeasurement(this.bpm, {this.contactLost = false});

  final int bpm;

  /// The sensor says it is not touching skin, so the number is not trusted.
  final bool contactLost;
}

/// Reads a Heart Rate Measurement packet. Returns null for a packet that is
/// too short or holds a rate that cannot be real.
HrMeasurement? parseHeartRateMeasurement(List<int> data) {
  if (data.length < 2) return null;
  final flags = data[0];
  final wide = flags & 0x01 != 0;
  if (wide && data.length < 3) return null;
  final bpm = wide ? data[1] | (data[2] << 8) : data[1];
  // Bits 1-2: 0/1 = contact not supported, 2 = supported but lost, 3 = detected.
  final contact = (flags >> 1) & 0x03;
  if (bpm < 30 || bpm > 250) {
    return contact == 2 ? const HrMeasurement(0, contactLost: true) : null;
  }
  return HrMeasurement(bpm, contactLost: contact == 2);
}

/// Estimated top heart rate for an age (Tanaka: 208 - 0.7 x age), which fits
/// people of all ages better than the old "220 minus age".
int maxHeartRate(int age) => (208 - 0.7 * age.clamp(10, 100)).round();

enum HrZone {
  rest('Resting', 0.0),
  warm('Warm-up', 0.50),
  steady('Steady', 0.60),
  push('Pushing', 0.70),
  peak('Peak', 0.85);

  const HrZone(this.label, this.from);

  final String label;

  /// Share of the top heart rate where the zone starts.
  final double from;

  /// Arc minutes earned per minute spent here. Follows the health guidelines
  /// behind "150 minutes a week": a moderate minute counts once and a
  /// vigorous minute counts twice.
  int get arcPerMinute => switch (this) {
    rest => 0,
    warm || steady => 1,
    push || peak => 2,
  };
}

HrZone zoneFor(int bpm, int maxBpm) {
  final share = bpm / maxBpm;
  var zone = HrZone.rest;
  for (final z in HrZone.values) {
    if (share >= z.from) zone = z;
  }
  return zone;
}

/// Arc minutes to collect in a week. 150 is the usual advice for adults.
const weeklyArcGoal = 150;

/// A workout in progress: every reading adds the time since the one before to
/// the zone it was in.
class HrSession {
  HrSession({required this.maxBpm});

  final int maxBpm;
  final Map<HrZone, double> _seconds = {for (final z in HrZone.values) z: 0};
  DateTime? _lastAt;
  int? _lastBpm;
  int _sum = 0;
  int _count = 0;

  int? current;
  int top = 0;
  double seconds = 0;

  /// Longer than this between readings means the link dropped: the gap is not
  /// counted, so a lost signal never earns anything.
  static const gap = Duration(seconds: 6);

  void add(int bpm, DateTime at) {
    final last = _lastAt;
    final lastBpm = _lastBpm;
    if (last != null && lastBpm != null) {
      final dt = at.difference(last);
      if (dt > Duration.zero && dt <= gap) {
        final s = dt.inMilliseconds / 1000;
        _seconds[zoneFor(lastBpm, maxBpm)] = _seconds[zoneFor(lastBpm, maxBpm)]! + s;
        seconds += s;
      }
    }
    _lastAt = at;
    _lastBpm = bpm;
    current = bpm;
    _sum += bpm;
    _count++;
    if (bpm > top) top = bpm;
  }

  int get average => _count == 0 ? 0 : (_sum / _count).round();

  double secondsIn(HrZone z) => _seconds[z]!;

  /// Arc minutes earned so far.
  double get arcMinutes =>
      [for (final z in HrZone.values) _seconds[z]! / 60 * z.arcPerMinute].fold(0.0, (a, b) => a + b);

  HrZone? get zone => current == null ? null : zoneFor(current!, maxBpm);
}

/// A finished session, as kept in the log.
class ArcEntry {
  const ArcEntry({required this.day, required this.arc});

  /// yyyy-MM-dd
  final String day;
  final double arc;
}

/// Arc minutes over the last seven days ending on [today].
double weekArcMinutes(Map<String, double> byDay, DateTime today) {
  var sum = 0.0;
  for (var i = 0; i < 7; i++) {
    final d = DateTime(today.year, today.month, today.day - i);
    sum += byDay[dayKey(d)] ?? 0;
  }
  return sum;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
