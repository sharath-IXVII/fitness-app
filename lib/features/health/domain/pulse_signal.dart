import 'dart:math' as math;

/// One camera frame while a fingertip covers the lens and flash: how bright
/// it was, and whether a finger seems to be there. The brightness rises and
/// falls a little with every heartbeat.
class PulseSample {
  const PulseSample(this.micros, this.value, {this.fingerOn = true});

  final int micros;
  final double value;
  final bool fingerOn;
}

/// A heart rate worked out from the signal.
class PulseEstimate {
  const PulseEstimate(this.bpm, this.confidence);

  final double bpm;

  /// 0 to 1: how regular the beat looks in the signal.
  final double confidence;
}

/// Heart rate from a fingertip camera signal (photoplethysmography), by
/// finding how often the signal repeats. It is an estimate, good to a few
/// beats per minute when the finger is still and the signal is clean.
///
/// [samples] are in time order. Returns null if there is too little signal or
/// no clear rhythm.
PulseEstimate? estimateHeartRate(List<PulseSample> samples, {double minSeconds = 8}) {
  const fs = 30.0; // resampled to a steady 30 readings a second
  if (samples.length < 20) return null;
  final t0 = samples.first.micros;
  final span = (samples.last.micros - t0) / 1e6;
  if (span < minSeconds) return null;

  // Resample to an even rate by straight-line interpolation.
  final n = (span * fs).floor();
  final x = List<double>.filled(n, 0);
  var j = 0;
  for (var i = 0; i < n; i++) {
    final t = t0 + (i / fs * 1e6);
    while (j < samples.length - 2 && samples[j + 1].micros < t) {
      j++;
    }
    final a = samples[j], b = samples[j + 1];
    final dt = (b.micros - a.micros).toDouble();
    final f = dt <= 0 ? 0.0 : ((t - a.micros) / dt).clamp(0.0, 1.0);
    x[i] = a.value + (b.value - a.value) * f;
  }

  // Remove the slow drift (about 1.5 s average), then smooth a little.
  final detrended = _minus(x, _movingAverage(x, 45));
  final y = _movingAverage(detrended, 5);

  // Leave out the ends, where the averages are not trustworthy.
  final trimmed = y.sublist(20, y.length - 20);
  if (trimmed.length < fs * 6) return null;
  final mean = trimmed.reduce((a, b) => a + b) / trimmed.length;
  final z = [for (final v in trimmed) v - mean];
  final energy = z.fold<double>(0, (a, v) => a + v * v) / z.length;
  if (energy < 1e-9) return null;

  // How well the signal matches itself shifted by each lag, for 40 to 200 bpm.
  final minLag = (fs * 60 / 200).ceil();
  final maxLag = math.min((fs * 60 / 40).floor(), z.length ~/ 2);
  final r = List<double>.filled(maxLag + 2, 0);
  for (var lag = minLag - 1; lag <= maxLag + 1; lag++) {
    var s = 0.0;
    for (var i = 0; i + lag < z.length; i++) {
      s += z[i] * z[i + lag];
    }
    r[lag] = (s / (z.length - lag)) / energy;
  }

  // A steady beat repeats every beat, every two beats, every three... so the
  // strongest repeat can be several beats long. Take the shortest repeat that
  // is nearly as strong as the strongest: that is one beat.
  var strongest = 0.0;
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (r[lag] > strongest) strongest = r[lag];
  }
  if (strongest <= 0) return null;
  var best = -1;
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (_isPeak(r, lag) && r[lag] >= 0.65 * strongest) {
      best = lag;
      break;
    }
  }
  if (best < 0) return null;
  if (!_isPeak(r, best) || r[best] <= 0) return null;

  // Sharpen the peak between samples.
  final a = r[best - 1], b = r[best], c = r[best + 1];
  final denom = a - 2 * b + c;
  final shift = denom == 0 ? 0.0 : 0.5 * (a - c) / denom;
  final lag = best + shift.clamp(-0.5, 0.5);
  var bpm = 60 * fs / lag;
  var confidence = r[best].clamp(0.0, 1.0);

  // Cross-check by counting beats directly.
  final counted = _bpmFromPeaks(z, fs);
  if (counted != null && (counted - bpm).abs() > 10) confidence *= 0.6;
  if (bpm < 40 || bpm > 200) return null;
  return PulseEstimate(bpm, confidence);
}

bool _isPeak(List<double> r, int i) => i > 0 && i < r.length - 1 && r[i] >= r[i - 1] && r[i] >= r[i + 1];

List<double> _movingAverage(List<double> v, int window) {
  final out = List<double>.filled(v.length, 0);
  final half = window ~/ 2;
  var sum = 0.0;
  var count = 0;
  // A running sum over a window centred on each point.
  var lo = 0, hi = -1;
  for (var i = 0; i < v.length; i++) {
    final wantHi = math.min(v.length - 1, i + half);
    final wantLo = math.max(0, i - half);
    while (hi < wantHi) {
      hi++;
      sum += v[hi];
      count++;
    }
    while (lo < wantLo) {
      sum -= v[lo];
      lo++;
      count--;
    }
    out[i] = sum / count;
  }
  return out;
}

List<double> _minus(List<double> a, List<double> b) => [for (var i = 0; i < a.length; i++) a[i] - b[i]];

/// A second opinion: the typical gap between heartbeats in the signal.
double? _bpmFromPeaks(List<double> z, double fs) {
  final std = math.sqrt(z.fold<double>(0, (a, v) => a + v * v) / z.length);
  final peaks = <int>[];
  final minGap = (fs * 0.3).round(); // no faster than 200 bpm
  for (var i = 1; i < z.length - 1; i++) {
    if (z[i] > 0.3 * std && z[i] >= z[i - 1] && z[i] > z[i + 1]) {
      if (peaks.isNotEmpty && i - peaks.last < minGap) {
        if (z[i] > z[peaks.last]) peaks[peaks.length - 1] = i;
      } else {
        peaks.add(i);
      }
    }
  }
  if (peaks.length < 6) return null;
  final gaps = [for (var i = 1; i < peaks.length; i++) (peaks[i] - peaks[i - 1]) / fs]..sort();
  final median = gaps[gaps.length ~/ 2];
  return median <= 0 ? null : 60 / median;
}

/// What a measurement came to.
enum PulseStatus { needFinger, measuring, done, unsteady }

class PulseResult {
  const PulseResult(this.status, {this.bpm, this.confidence = 0});

  final PulseStatus status;
  final int? bpm;
  final double confidence;
}

/// Collects frames while a finger is on the camera, shows a live rate, and
/// gives the final heart rate after [seconds] of steady signal.
class PulseMeter {
  PulseMeter({this.seconds = 30, this.maxSeconds = 50});

  /// Steady seconds needed for a result.
  final double seconds;

  /// Give up and say "unsteady" after this long without a steady result.
  final double maxSeconds;

  final _samples = <PulseSample>[];
  bool _fingerOn = false;

  bool get fingerOn => _fingerOn;

  /// Seconds of signal collected with the finger in place.
  double get validSeconds => _samples.length < 2 ? 0 : (_samples.last.micros - _samples.first.micros) / 1e6;

  double get progress => (validSeconds / seconds).clamp(0.0, 1.0);

  /// The most recent values, for drawing the pulse wave.
  List<double> recentValues([int count = 150]) {
    final v = [for (final s in _samples) s.value];
    final tail = v.length > count ? v.sublist(v.length - count) : v;
    if (tail.isEmpty) return const [];
    final avg = tail.reduce((a, b) => a + b) / tail.length;
    return [for (final x in tail) x - avg];
  }

  void add(PulseSample s) {
    _fingerOn = s.fingerOn;
    if (!s.fingerOn) {
      // Lifting the finger starts the count again.
      _samples.clear();
      return;
    }
    _samples.add(s);
    final cutoff = s.micros - (maxSeconds * 1e6).round();
    while (_samples.isNotEmpty && _samples.first.micros < cutoff) {
      _samples.removeAt(0);
    }
  }

  /// A rate from the last ten seconds, shown while measuring.
  PulseEstimate? get live {
    if (_samples.isEmpty) return null;
    final from = _samples.last.micros - 10 * 1000000;
    final recent = [
      for (final s in _samples)
        if (s.micros >= from) s,
    ];
    return estimateHeartRate(recent, minSeconds: 7);
  }

  PulseResult get result {
    if (!_fingerOn && _samples.isEmpty) return const PulseResult(PulseStatus.needFinger);
    if (validSeconds < seconds) return const PulseResult(PulseStatus.measuring);
    final end = _samples.last.micros;
    List<PulseSample> window(double fromAgo, double toAgo) => [
      for (final s in _samples)
        if (s.micros >= end - fromAgo * 1e6 && s.micros <= end - toAgo * 1e6) s,
    ];
    final a = estimateHeartRate(window(20, 0));
    final b = estimateHeartRate(window(20, 5));
    if (a != null && b != null && a.confidence >= 0.4 && b.confidence >= 0.4 && (a.bpm - b.bpm).abs() <= 6) {
      return PulseResult(PulseStatus.done, bpm: a.bpm.round(), confidence: math.min(a.confidence, b.confidence));
    }
    if (validSeconds >= maxSeconds - 1) return const PulseResult(PulseStatus.unsteady);
    return const PulseResult(PulseStatus.measuring);
  }
}
