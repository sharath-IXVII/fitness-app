import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'rep_counter.dart';

/// Measures dancing from the camera: seconds count only while the body is in
/// view and really moving (arms and legs together, not one waving hand).
/// Standing still pauses the count; it never goes back down.
class DanceMeter {
  DanceMeter({this.goal = const Duration(seconds: 20)});

  final Duration goal;

  /// Seconds of dancing so far.
  Duration danced = Duration.zero;

  /// Smoothed movement, 0 (still) to 1 (dancing hard).
  double energy = 0;

  /// Whether enough of the body is in the frame.
  bool visible = false;

  /// Coaching line, or null while all is well.
  String? hint;

  static const _joints = [
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  /// Movement counted as dancing (body sizes per second, smoothed).
  static const moving = 0.35;

  /// Joints whose speed counts as "this part is moving".
  static const _partSpeed = 0.5;

  Map<PoseLandmarkType, (double, double)>? _last;
  Duration? _lastAt;

  bool get done => danced >= goal;
  double get progress => (danced.inMilliseconds / goal.inMilliseconds).clamp(0.0, 1.0);
  int get secondsLeft => math.max(0, ((goal - danced).inMilliseconds / 1000).ceil());

  /// Feeds one camera frame taken at [now].
  void update(Landmarks? lm, Duration now) {
    final prevAt = _lastAt;
    _lastAt = now;
    final pts = <PoseLandmarkType, (double, double)>{
      for (final t in _joints)
        if (lm?[t] case final p? when p.likelihood >= RepCounter.minVisibility) t: (p.x, p.y),
    };
    final ls = pts[PoseLandmarkType.leftShoulder], rs = pts[PoseLandmarkType.rightShoulder];
    final lh = pts[PoseLandmarkType.leftHip], rh = pts[PoseLandmarkType.rightHip];
    visible = pts.length >= 8 && (ls != null || rs != null) && (lh != null || rh != null);
    if (!visible) {
      hint = 'Step back so your whole body is in the frame';
      energy *= 0.8;
      _last = null;
      return;
    }
    // Body size: shoulder to hip, so near and far dancers score the same.
    final s = ls ?? rs!, h = lh ?? rh!;
    final size = math.max(1.0, math.sqrt(math.pow(s.$1 - h.$1, 2) + math.pow(s.$2 - h.$2, 2)));
    final last = _last;
    _last = pts;
    if (last == null || prevAt == null) return;
    final dt = (now - prevAt).inMilliseconds / 1000;
    // A long gap between frames isn't movement.
    if (dt <= 0 || dt > 0.5) return;

    var sum = 0.0, n = 0;
    var arms = false, legs = false;
    for (final e in pts.entries) {
      final was = last[e.key];
      if (was == null) continue;
      final v = math.sqrt(math.pow(e.value.$1 - was.$1, 2) + math.pow(e.value.$2 - was.$2, 2)) / size / dt;
      // One wild jump of a joint (a detection glitch) can't carry a frame.
      final speed = math.min(v, 4.0);
      sum += speed;
      n++;
      if (speed > _partSpeed) {
        final name = e.key.name;
        if (name.contains('Wrist') || name.contains('Elbow')) arms = true;
        if (name.contains('Knee') || name.contains('Ankle') || name.contains('Hip')) legs = true;
      }
    }
    if (n == 0) return;
    final frame = sum / n;
    energy = energy * 0.7 + math.min(frame, 1.5) / 1.5 * 0.3;
    // Dancing means the whole body: arms and legs both moving.
    final dancing = energy >= moving / 1.5 && arms && legs;
    if (dancing) {
      danced += now - prevAt;
      if (danced > goal) danced = goal;
      hint = null;
    } else {
      hint = arms && !legs ? 'Move your legs too!' : 'Keep dancing!';
    }
  }
}
