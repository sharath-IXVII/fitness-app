import 'dart:math' as math;

import 'package:fitalarm/features/alarm/domain/challenge.dart';
import 'package:fitalarm/features/workout/domain/dance_meter.dart';
import 'package:fitalarm/features/workout/domain/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// A standing person 100 px from shoulder to hip, with optional sways.
Landmarks _body({double arms = 0, double legs = 0, double all = 0, double seen = 0.9}) {
  PoseLandmark p(PoseLandmarkType t, double x, double y) =>
      PoseLandmark(type: t, x: x + all, y: y, z: 0, likelihood: seen);
  return {
    for (final l in [
      p(PoseLandmarkType.leftShoulder, 180, 200),
      p(PoseLandmarkType.rightShoulder, 120, 200),
      p(PoseLandmarkType.leftElbow, 200 + arms, 250 - arms),
      p(PoseLandmarkType.rightElbow, 100 - arms, 250 - arms),
      p(PoseLandmarkType.leftWrist, 210 + arms * 2, 300 - arms * 2),
      p(PoseLandmarkType.rightWrist, 90 - arms * 2, 300 - arms * 2),
      p(PoseLandmarkType.leftHip, 170, 300),
      p(PoseLandmarkType.rightHip, 130, 300),
      p(PoseLandmarkType.leftKnee, 170 + legs, 380 - legs),
      p(PoseLandmarkType.rightKnee, 130 - legs, 380),
      p(PoseLandmarkType.leftAnkle, 170 + legs, 460 - legs),
      p(PoseLandmarkType.rightAnkle, 130 - legs, 460),
    ])
      l.type: l,
  };
}

/// Feeds [seconds] of frames at 15 fps; [pose] gives each frame's body.
DanceMeter _run(Landmarks? Function(int frame) pose, {int seconds = 25}) {
  final m = DanceMeter();
  for (var f = 0; f < seconds * 15; f++) {
    m.update(pose(f), Duration(milliseconds: f * 1000 ~/ 15));
    if (m.done) break;
  }
  return m;
}

void main() {
  test('Dance is a camera option, not a brain game', () {
    expect(AlarmChallenge.values, contains(AlarmChallenge.dance));
    expect(AlarmChallenge.dance.isGame, isFalse);
    expect(AlarmChallenge.math.isGame, isTrue);
  });

  test('standing still never counts', () {
    final m = _run((_) => _body());
    expect(m.danced, Duration.zero);
    expect(m.hint, 'Keep dancing!');
  });

  test('waving one pair of arms alone is not dancing', () {
    final m = _run((f) => _body(arms: 30 * math.sin(f / 2)));
    expect(m.danced.inSeconds, lessThan(3));
    expect(m.hint, 'Move your legs too!');
  });

  test('dancing with arms and legs reaches 20 seconds, and no more', () {
    final m = _run((f) => _body(arms: 35 * math.sin(f / 2), legs: 25 * math.sin(f / 2 + 1), all: 15 * math.sin(f / 4)));
    expect(m.done, isTrue);
    expect(m.danced, const Duration(seconds: 20));
    expect(m.secondsLeft, 0);
    expect(m.progress, 1.0);
  });

  test('stopping halfway pauses the count; it never goes back down', () {
    final m = DanceMeter();
    var t = 0;
    void feed(int frames, Landmarks? Function(int f) pose) {
      for (var i = 0; i < frames; i++, t++) {
        m.update(pose(t), Duration(milliseconds: t * 1000 ~/ 15));
      }
    }

    feed(150, (f) => _body(arms: 35 * math.sin(f / 2), legs: 25 * math.sin(f / 2 + 1)));
    final after10 = m.danced;
    expect(after10.inSeconds, greaterThanOrEqualTo(7));
    feed(150, (_) => _body());
    expect(m.danced.inMilliseconds, lessThan(after10.inMilliseconds + 1500));
    expect(m.danced, greaterThanOrEqualTo(after10));
  });

  test('out of view does not count, and says to step back', () {
    final m = _run((f) => f.isEven ? null : _body(arms: 40, legs: 40, seen: 0.2), seconds: 5);
    expect(m.danced, Duration.zero);
    expect(m.visible, isFalse);
    expect(m.hint, contains('Step back'));
  });
}
