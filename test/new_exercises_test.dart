import 'dart:math' as math;

import 'package:fitalarm/features/workout/domain/exercise.dart';
import 'package:fitalarm/features/workout/domain/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

typedef T = PoseLandmarkType;

PoseLandmark _lm(T t, (double, double) p) => PoseLandmark(type: t, x: p.$1, y: p.$2, z: 0, likelihood: 0.95);

/// Point [len] away from [from] in direction [deg] (0 = right, 90 = down).
(double, double) _go((double, double) from, double len, double deg) =>
    (from.$1 + len * math.cos(deg * math.pi / 180), from.$2 + len * math.sin(deg * math.pi / 180));

/// Front view, standing, with each elbow bent to [left]/[right] degrees
/// (upper arms hanging down, forearms swinging forward-up).
Landmarks curl(double left, double right) {
  final out = <T, PoseLandmark>{};
  for (final (sign, elbowDeg, sh, el, wr, hip) in [
    (-1.0, left, T.leftShoulder, T.leftElbow, T.leftWrist, T.leftHip),
    (1.0, right, T.rightShoulder, T.rightElbow, T.rightWrist, T.rightHip),
  ]) {
    final s = (200 + sign * 40, 150.0);
    final e = _go(s, 60, 90);
    // Forearm direction: straight down (90°) at 180° elbow, folding up towards the shoulder.
    final w = _go(e, 55, 90 + sign * (180 - elbowDeg));
    out[sh] = _lm(sh, s);
    out[el] = _lm(el, e);
    out[wr] = _lm(wr, w);
    out[hip] = _lm(hip, (s.$1, 300));
  }
  return out;
}

/// Front view with both arms raised sideways to [deg] from the body.
Landmarks lateral(double deg) {
  final out = <T, PoseLandmark>{};
  for (final (sign, sh, el, wr, hip) in [
    (-1.0, T.leftShoulder, T.leftElbow, T.leftWrist, T.leftHip),
    (1.0, T.rightShoulder, T.rightElbow, T.rightWrist, T.rightHip),
  ]) {
    final s = (200 + sign * 40, 150.0);
    final dir = sign < 0 ? 90 + deg : 90 - deg;
    out[sh] = _lm(sh, s);
    out[el] = _lm(el, _go(s, 60, dir));
    out[wr] = _lm(wr, _go(s, 115, dir));
    out[hip] = _lm(hip, (s.$1, 300));
  }
  return out;
}

/// Front view shoulder press: [top] = arms straight overhead, else hands at shoulders.
Landmarks press({required bool top}) {
  final out = <T, PoseLandmark>{};
  for (final (sign, sh, el, wr) in [
    (-1.0, T.leftShoulder, T.leftElbow, T.leftWrist),
    (1.0, T.rightShoulder, T.rightElbow, T.rightWrist),
  ]) {
    final s = (200 + sign * 40, 150.0);
    if (top) {
      out[el] = _lm(el, _go(s, 60, 270));
      out[wr] = _lm(wr, _go(s, 115, 270));
    } else {
      final e = _go(s, 60, sign < 0 ? 135 : 45); // elbow out and down
      out[el] = _lm(el, e);
      out[wr] = _lm(wr, (e.$1, s.$2 - 5)); // wrist above the elbow, at shoulder height
    }
    out[sh] = _lm(sh, s);
  }
  return out;
}

/// Side view, one side only: shoulder, hip, knee, ankle from a hip angle and
/// knee angle, with the torso at [torsoDeg] direction from the hip.
Landmarks side({
  required double torsoDeg,
  required double hipAngle,
  required double kneeAngle,
  bool withArms = false,
  double elbowAngle = 180,
}) {
  final hip = (200.0, 300.0);
  final shoulder = _go(hip, 110, torsoDeg);
  final thighDeg = torsoDeg + hipAngle; // rotate away from the torso
  final knee = _go(hip, 100, thighDeg);
  final ankle = _go(knee, 100, thighDeg - (180 - kneeAngle));
  final out = {
    T.leftShoulder: _lm(T.leftShoulder, shoulder),
    T.leftHip: _lm(T.leftHip, hip),
    T.leftKnee: _lm(T.leftKnee, knee),
    T.leftAnkle: _lm(T.leftAnkle, ankle),
  };
  if (withArms) {
    final elbow = _go(shoulder, 60, 90);
    out[T.leftElbow] = _lm(T.leftElbow, elbow);
    out[T.leftWrist] = _lm(T.leftWrist, _go(elbow, 55, 90 + (180 - elbowAngle)));
  }
  return out;
}

/// Feeds [frames] 100 ms apart (each repeated to settle smoothing) and returns reps.
var _clock = Duration.zero;

int run(RepCounter c, List<Landmarks> frames, {int repeat = 6}) {
  var t = _clock;
  for (final f in frames) {
    for (var i = 0; i < repeat; i++) {
      c.update(f, t);
      t += const Duration(milliseconds: 100);
    }
  }
  _clock = t;
  return c.reps;
}

void main() {
  test('every exercise has a counter and sensible defaults', () {
    for (final e in Exercise.values) {
      expect(RepCounter.of(e), isA<RepCounter>());
      expect(e.defaultTarget, greaterThan(0));
      expect(e.muscles, isNotEmpty);
    }
    expect(Exercise.values.map((e) => e.name), isNot(contains('pullUp')));
  });

  test('my curl helper produces the requested elbow angle', () {
    final f = curl(40, 170);
    expect(jointAngle(f[T.leftShoulder]!, f[T.leftElbow]!, f[T.leftWrist]!), closeTo(40, 0.5));
    expect(jointAngle(f[T.rightShoulder]!, f[T.rightElbow]!, f[T.rightWrist]!), closeTo(170, 0.5));
  });

  test('biceps curls: alternating arms each count, both together count once', () {
    final c = BicepCurlCounter();
    expect(run(c, [curl(170, 170), curl(40, 170), curl(170, 170), curl(170, 40), curl(170, 170)]), 2);
    expect(run(c, [curl(40, 40), curl(170, 170)]), 3);
    // Half curls don't count.
    expect(run(c, [curl(90, 90), curl(170, 170)]), 3);
  });

  test('lateral raises', () {
    final c = LateralRaiseCounter();
    expect(run(c, [lateral(10), lateral(85), lateral(10), lateral(50), lateral(10), lateral(85), lateral(10)]), 2);
  });

  test('shoulder press counts at the top after starting at the shoulders', () {
    final c = ShoulderPressCounter();
    expect(run(c, [press(top: true), press(top: false), press(top: true), press(top: false), press(top: true)]), 2);
  });

  test('sit-ups', () {
    // Lying: torso pointing left (180°), thighs up-right, knees bent.
    Landmarks f(double hip) => side(torsoDeg: 180, hipAngle: hip, kneeAngle: 80);
    final c = SitUpCounter();
    expect(run(c, [f(130), f(60), f(130), f(60), f(100), f(60)]), 2);
  });

  test('glute bridges', () {
    Landmarks f(double hip) => side(torsoDeg: 175, hipAngle: hip, kneeAngle: 90);
    final c = GluteBridgeCounter();
    expect(run(c, [f(130), f(175), f(130), f(175), f(150), f(175)]), 2);
  });

  test('wall sit only times a 90° hold with an upright back', () {
    final c = WallSitTimer();
    run(c, [side(torsoDeg: 270, hipAngle: 90, kneeAngle: 90)], repeat: 31); // 3 s
    expect(c.progress, 3);
    run(c, [side(torsoDeg: 270, hipAngle: 160, kneeAngle: 170)], repeat: 20); // standing
    expect(c.progress, 3);
    expect(c.hint, isNotNull);
  });

  test('burpees count on returning to standing after the floor', () {
    final stand = side(torsoDeg: 270, hipAngle: 180, kneeAngle: 180);
    final floor = side(torsoDeg: 180, hipAngle: 180, kneeAngle: 180);
    final squat = side(torsoDeg: 260, hipAngle: 80, kneeAngle: 80);
    final c = BurpeeCounter();
    expect(run(c, [stand, squat, floor, squat, stand, squat, stand, floor, stand]), 2);
  });

  test('knee push-ups use the knee as the end of the body line', () {
    // Horizontal body facing left, hips-knees in line; arms below shoulders.
    Landmarks f(double elbow) => side(torsoDeg: 180, hipAngle: 180, kneeAngle: 90, withArms: true, elbowAngle: elbow);
    final c = PushUpCounter(kneeling: true);
    expect(run(c, [f(170), f(80), f(170), f(80), f(170)]), 2);
    expect(c.hint, isNull);
  });

  test('mountain climbers count each knee drive', () {
    Landmarks f(double hip) {
      final b = side(torsoDeg: 180, hipAngle: hip, kneeAngle: 90, withArms: true);
      return b;
    }

    final c = MountainClimberCounter();
    expect(run(c, [f(175), f(80), f(175), f(80), f(175)]), 2);
  });

  test('triceps dips', () {
    // Sitting upright, arms behind: upper arm hangs down, forearm folds.
    Landmarks f(double elbow) => side(torsoDeg: 270, hipAngle: 90, kneeAngle: 90, withArms: true, elbowAngle: elbow);
    final c = TricepDipCounter();
    expect(run(c, [f(170), f(85), f(170), f(85), f(170)]), 2);
  });
}
