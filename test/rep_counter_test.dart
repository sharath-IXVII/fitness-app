import 'dart:math' as math;

import 'package:fitalarm/features/workout/domain/exercise.dart';
import 'package:fitalarm/features/workout/domain/rep_counter.dart';
import 'package:fitalarm/features/workout/domain/routine.dart';
import 'package:fitalarm/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

PoseLandmark _lm(PoseLandmarkType t, double x, double y, [double likelihood = 0.95]) =>
    PoseLandmark(type: t, x: x, y: y, z: 0, likelihood: likelihood);

/// A front-facing body (image coords, y down) with both knees bent to
/// [kneeAngle] degrees, arms at [armsUp] and feet [feetApart] wide.
Landmarks standing({double kneeAngle = 180, bool armsUp = false, double feetApart = 80}) {
  const hipY = 300.0, thigh = 100.0, shin = 100.0;
  final bend = (180 - kneeAngle) * math.pi / 180;
  // Thigh tilts forward by bend/2, shin back by bend/2 → interior angle = kneeAngle.
  final kneeX = thigh * math.sin(bend / 2), kneeY = hipY + thigh * math.cos(bend / 2);
  final ankleY = kneeY + shin * math.cos(bend / 2);
  final out = <PoseLandmarkType, PoseLandmark>{};
  for (final (sign, sh, hip, knee, ankle, wrist, elbow) in [
    (
      -1.0,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftElbow,
    ),
    (
      1.0,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightElbow,
    ),
  ]) {
    final cx = 200 + sign * 40;
    out[sh] = _lm(sh, cx, 150);
    out[hip] = _lm(hip, cx, hipY);
    out[knee] = _lm(knee, cx + kneeX, kneeY);
    out[ankle] = _lm(ankle, 200 + sign * feetApart / 2, ankleY);
    out[wrist] = _lm(wrist, cx + sign * 20, armsUp ? 60 : 260);
    out[elbow] = _lm(elbow, cx + sign * 10, armsUp ? 100 : 210);
  }
  return out;
}

/// Side view, body horizontal, elbows at [elbowAngle].
Landmarks pushUp(double elbowAngle) {
  const shoulder = (100.0, 200.0);
  final upper = 60.0, fore = 60.0;
  final a = elbowAngle * math.pi / 180;
  // Upper arm points straight down from the shoulder; forearm opens by elbowAngle.
  final elbow = (shoulder.$1, shoulder.$2 + upper);
  final wrist = (elbow.$1 + fore * math.sin(math.pi - a), elbow.$2 + fore * math.cos(math.pi - a));
  return {
    PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, shoulder.$1, shoulder.$2),
    PoseLandmarkType.leftElbow: _lm(PoseLandmarkType.leftElbow, elbow.$1, elbow.$2),
    PoseLandmarkType.leftWrist: _lm(PoseLandmarkType.leftWrist, wrist.$1, wrist.$2),
    PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 250, 205),
    PoseLandmarkType.leftAnkle: _lm(PoseLandmarkType.leftAnkle, 420, 215),
  };
}

void main() {
  test('joint angle', () {
    final a = _lm(PoseLandmarkType.leftHip, 0, 0);
    final b = _lm(PoseLandmarkType.leftKnee, 0, 10);
    expect(jointAngle(a, b, _lm(PoseLandmarkType.leftAnkle, 0, 20)), closeTo(180, 0.01));
    expect(jointAngle(a, b, _lm(PoseLandmarkType.leftAnkle, 10, 10)), closeTo(90, 0.01));
  });

  test('test body helper produces the requested knee angle', () {
    final b = standing(kneeAngle: 90);
    expect(
      jointAngle(b[PoseLandmarkType.leftHip]!, b[PoseLandmarkType.leftKnee]!, b[PoseLandmarkType.leftAnkle]!),
      closeTo(90, 0.5),
    );
  });

  group('squats', () {
    test('a full squat counts once, on the way up', () {
      final c = SquatCounter();
      var t = 0;
      Duration next() => Duration(milliseconds: t += 100);
      for (final angle in <double>[175.0, 150, 120, 85, 80, 85, 120, 150, 175, 178, 178]) {
        c.update(standing(kneeAngle: angle), next());
      }
      expect(c.reps, 1);
    });

    test('half squats do not count and get a hint', () {
      final c = SquatCounter();
      var t = 0;
      for (var rep = 0; rep < 3; rep++) {
        for (final angle in <double>[178.0, 150, 125, 120, 125, 150, 178, 178, 178]) {
          c.update(standing(kneeAngle: angle), Duration(milliseconds: t += 100));
        }
      }
      expect(c.reps, 0);
      expect(c.hint, contains('lower'));
    });

    test('missing body parts are reported, not counted', () {
      final c = SquatCounter();
      expect(c.update(null, Duration.zero), isFalse);
      expect(c.visible, isFalse);
      expect(c.hint, isNotNull);

      final lowConfidence = standing(kneeAngle: 80)
          .map((k, v) => MapEntry(k, PoseLandmark(type: k, x: v.x, y: v.y, z: 0, likelihood: 0.1)));
      c.update(lowConfidence, Duration.zero);
      expect(c.visible, isFalse);
    });

    test('jitter faster than a human rep is ignored', () {
      final c = SquatCounter();
      var t = 0;
      for (var i = 0; i < 6; i++) {
        for (final angle in <double>[70.0, 70, 179, 179, 179]) {
          c.update(standing(kneeAngle: angle), Duration(milliseconds: t += 20));
        }
      }
      expect(c.reps, lessThan(3));
    });
  });

  test('push-ups count a full lower and press', () {
    final c = PushUpCounter();
    var t = 0;
    for (var rep = 0; rep < 3; rep++) {
      for (final angle in <double>[170.0, 140, 100, 80, 75, 80, 120, 160, 170, 170]) {
        c.update(pushUp(angle), Duration(milliseconds: t += 100));
      }
    }
    expect(c.reps, 3);
  });

  test('push-ups are not counted while standing', () {
    final c = PushUpCounter();
    var t = 0;
    for (var rep = 0; rep < 3; rep++) {
      for (final angle in <double>[170.0, 80, 170]) {
        final body = standing();
        // Same arm motion, but body vertical.
        final p = pushUp(angle);
        body[PoseLandmarkType.leftElbow] = p[PoseLandmarkType.leftElbow]!;
        body[PoseLandmarkType.leftWrist] = p[PoseLandmarkType.leftWrist]!;
        c.update(body, Duration(milliseconds: t += 300));
      }
    }
    expect(c.reps, 0);
  });

  test('jumping jacks count open then close', () {
    final c = JumpingJackCounter();
    var t = 0;
    for (var rep = 0; rep < 4; rep++) {
      c.update(standing(), Duration(milliseconds: t += 250));
      c.update(standing(armsUp: true, feetApart: 140), Duration(milliseconds: t += 250));
      c.update(standing(), Duration(milliseconds: t += 250));
    }
    expect(c.reps, 4);
  });

  test('plank only times while the body is straight and horizontal', () {
    Landmarks plank(double hipDrop) => {
      PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 100, 200),
      PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 250, 210 + hipDrop),
      PoseLandmarkType.leftAnkle: _lm(PoseLandmarkType.leftAnkle, 400, 220),
    };
    final c = PlankTimer();
    var t = 0;
    for (var i = 0; i <= 30; i++) {
      c.update(plank(0), Duration(milliseconds: t += 100));
    }
    expect(c.progress, 3);
    for (var i = 0; i < 30; i++) {
      c.update(plank(80), Duration(milliseconds: t += 100));
    }
    expect(c.progress, 3);
    expect(c.hint, 'Lift your hips');
  });

  test('session moves through every step and finishes', () {
    const routine = Routine(
      id: 'x',
      name: 'Test',
      steps: [RoutineStep(Exercise.squat, 2), RoutineStep(Exercise.jumpingJack, 1)],
    );
    final s = WorkoutSession(routine);
    var t = 0;
    final events = <SessionEvent>[];
    void feed(Landmarks b) => events.add(s.update(b, Duration(milliseconds: t += 200)));
    for (var i = 0; i < 2; i++) {
      for (final a in <double>[178.0, 120, 80, 120, 178]) {
        // Two frames per pose, like a real ~10 fps stream.
        feed(standing(kneeAngle: a));
        feed(standing(kneeAngle: a));
      }
    }
    expect(events.where((e) => e == SessionEvent.stepDone), hasLength(1));
    expect(s.current.exercise, Exercise.jumpingJack);
    feed(standing(armsUp: true, feetApart: 140));
    feed(standing());
    feed(standing());
    expect(s.finished, isTrue);
    expect(events, contains(SessionEvent.finished));
    expect(s.results, [2, 1]);
  });
}
