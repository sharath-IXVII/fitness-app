import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise.dart';

typedef Landmarks = Map<PoseLandmarkType, PoseLandmark>;

/// Turns a stream of body landmarks into counted reps (or held seconds).
///
/// Each exercise is a small state machine over joint angles with hysteresis
/// (separate "down" and "up" thresholds), angle smoothing to absorb jitter,
/// and a minimum time per rep so waving at the camera doesn't count.
/// Coordinates are image-space with y growing downwards.
abstract class RepCounter {
  RepCounter();

  factory RepCounter.of(Exercise e) => switch (e) {
    Exercise.squat => SquatCounter(),
    Exercise.pushUp => PushUpCounter(),
    Exercise.jumpingJack => JumpingJackCounter(),
    Exercise.lunge => LungeCounter(),
    Exercise.highKnees => HighKneesCounter(),
    Exercise.plank => PlankTimer(),
    Exercise.kneePushUp => PushUpCounter(kneeling: true),
    Exercise.bicepCurl => BicepCurlCounter(),
    Exercise.tricepDip => TricepDipCounter(),
    Exercise.shoulderPress => ShoulderPressCounter(),
    Exercise.lateralRaise => LateralRaiseCounter(),
    Exercise.sitUp => SitUpCounter(),
    Exercise.gluteBridge => GluteBridgeCounter(),
    Exercise.mountainClimber => MountainClimberCounter(),
    Exercise.wallSit => WallSitTimer(),
    Exercise.burpee => BurpeeCounter(),
  };

  static const minVisibility = 0.5;
  static const minRepGap = Duration(milliseconds: 350);

  int reps = 0;

  /// How far into the current movement the user is, 0 (start) to 1 (bottom).
  double motion = 0;

  /// Coaching message for the user, or null when everything looks right.
  String? hint;

  /// Whether the body parts this exercise needs are in frame.
  bool visible = false;

  Duration? _lastRep;

  /// Value compared against the routine target (reps, or whole seconds).
  int get progress => reps;

  /// Feeds one frame. Returns true when this frame completed a rep.
  bool update(Landmarks? landmarks, Duration now);

  bool countRep(Duration now) {
    if (_lastRep != null && now - _lastRep! < minRepGap) return false;
    _lastRep = now;
    reps++;
    return true;
  }

  static const _notVisible = 'Step back so your whole body is in the frame';
  String get notVisibleHint => _notVisible;
}

// ---------------------------------------------------------------- geometry

PoseLandmark? _p(Landmarks lm, PoseLandmarkType t) {
  final l = lm[t];
  return l != null && l.likelihood >= RepCounter.minVisibility ? l : null;
}

/// Interior angle at [b] in degrees (0–180).
double jointAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final v1x = a.x - b.x, v1y = a.y - b.y;
  final v2x = c.x - b.x, v2y = c.y - b.y;
  final dot = v1x * v2x + v1y * v2y;
  final mag = math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y);
  if (mag == 0) return 180;
  return math.acos((dot / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
}

double _dist(PoseLandmark a, PoseLandmark b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// Angle of the a→b line from horizontal, 0–90 degrees.
double _tilt(PoseLandmark a, PoseLandmark b) {
  final deg = math.atan2((b.y - a.y).abs(), (b.x - a.x).abs()) * 180 / math.pi;
  return deg;
}

enum _Side { left, right }

const _sideJoints = {
  'shoulder': (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  'elbow': (PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow),
  'wrist': (PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist),
  'hip': (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  'knee': (PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee),
  'ankle': (PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle),
};

PoseLandmarkType _j(String joint, _Side s) => s == _Side.left ? _sideJoints[joint]!.$1 : _sideJoints[joint]!.$2;

/// Picks the body side whose [joints] are all visible with the highest
/// confidence — the side facing the camera in a side-on exercise.
Map<String, PoseLandmark>? _bestSide(Landmarks lm, List<String> joints) {
  Map<String, PoseLandmark>? best;
  var bestScore = -1.0;
  for (final side in _Side.values) {
    final pts = <String, PoseLandmark>{};
    for (final j in joints) {
      final p = _p(lm, _j(j, side));
      if (p == null) break;
      pts[j] = p;
    }
    if (pts.length != joints.length) continue;
    final score = pts.values.fold(0.0, (a, p) => a + p.likelihood);
    if (score > bestScore) {
      bestScore = score;
      best = pts;
    }
  }
  return best;
}

/// Exponential moving average to steady jittery angles.
class _Smooth {
  double? _v;
  double add(double x, [double alpha = 0.5]) => _v = _v == null ? x : _v! + alpha * (x - _v!);
}

double _ramp(double v, double from, double to) => ((v - from) / (to - from)).clamp(0.0, 1.0);

// ---------------------------------------------------------------- counters

/// Down when knees bend below ~100°, a rep when standing back up past ~160°.
class SquatCounter extends RepCounter {
  static const down = 100.0, up = 160.0;
  final _knee = _Smooth();
  bool _isDown = false;
  double _deepest = 180;

  @override
  bool update(Landmarks? lm, Duration now) {
    final angles = <double>[];
    if (lm != null) {
      for (final s in _Side.values) {
        final h = _p(lm, _j('hip', s)), k = _p(lm, _j('knee', s)), a = _p(lm, _j('ankle', s));
        if (h != null && k != null && a != null) angles.add(jointAngle(h, k, a));
      }
    }
    visible = angles.isNotEmpty;
    if (!visible) {
      hint = notVisibleHint;
      return false;
    }
    final knee = _knee.add(angles.reduce((a, b) => a + b) / angles.length);
    motion = _ramp(knee, 170, down);
    _deepest = math.min(_deepest, knee);

    if (!_isDown && knee < down) {
      _isDown = true;
      hint = null;
    } else if (knee > up) {
      if (_isDown) {
        _isDown = false;
        _deepest = 180;
        return countRep(now);
      }
      // Came back up without reaching depth.
      if (_deepest < 140) hint = 'Go a little lower — thighs parallel to the floor';
      _deepest = 180;
    }
    return false;
  }
}

/// Side view: body roughly horizontal, elbows below ~95° then back past ~150°.
/// With [kneeling], the knee replaces the ankle as the end of the body line.
class PushUpCounter extends RepCounter {
  PushUpCounter({this.kneeling = false});

  final bool kneeling;
  static const down = 95.0, up = 150.0;
  final _elbow = _Smooth();
  bool _isDown = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final end = kneeling ? 'knee' : 'ankle';
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'elbow', 'wrist', 'hip', end]);
    visible = pts != null;
    if (pts == null) {
      hint = 'Place the phone to your side so your whole body is visible';
      return false;
    }
    if (_tilt(pts['shoulder']!, pts[end]!) > (kneeling ? 50 : 40)) {
      hint = 'Get into push-up position';
      return false;
    }
    final straight = jointAngle(pts['shoulder']!, pts['hip']!, pts[end]!);
    hint = straight < 150 ? 'Keep your body in a straight line' : null;

    final elbow = _elbow.add(jointAngle(pts['shoulder']!, pts['elbow']!, pts['wrist']!));
    motion = _ramp(elbow, 165, down);
    if (!_isDown && elbow < down) {
      _isDown = true;
    } else if (_isDown && elbow > up) {
      _isDown = false;
      return countRep(now);
    }
    return false;
  }
}

/// Open = hands above the head and feet wider than the shoulders; a rep is
/// counted when the user returns to closed.
class JumpingJackCounter extends RepCounter {
  bool _isOpen = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final ls = lm == null ? null : _p(lm, PoseLandmarkType.leftShoulder);
    final rs = lm == null ? null : _p(lm, PoseLandmarkType.rightShoulder);
    final lw = lm == null ? null : _p(lm, PoseLandmarkType.leftWrist);
    final rw = lm == null ? null : _p(lm, PoseLandmarkType.rightWrist);
    final la = lm == null ? null : _p(lm, PoseLandmarkType.leftAnkle);
    final ra = lm == null ? null : _p(lm, PoseLandmarkType.rightAnkle);
    visible = ![ls, rs, lw, rw, la, ra].contains(null);
    if (!visible) {
      hint = notVisibleHint;
      return false;
    }
    hint = null;
    final shoulderW = math.max(_dist(ls!, rs!), 1.0);
    final shoulderY = (ls.y + rs.y) / 2;
    final feet = (la!.x - ra!.x).abs() / shoulderW;
    final armsUp = lw!.y < shoulderY && rw!.y < shoulderY;
    final armsDown = lw.y > shoulderY && rw!.y > shoulderY;
    motion = (_ramp(feet, 1.0, 1.6) + (armsUp ? 1 : 0)) / 2;

    if (!_isOpen && armsUp && feet > 1.3) {
      _isOpen = true;
    } else if (_isOpen && armsDown && feet < 1.1) {
      _isOpen = false;
      return countRep(now);
    }
    return false;
  }
}

/// Down when the front knee bends below ~105° (back knee also bent), a rep
/// when both legs straighten again.
class LungeCounter extends RepCounter {
  static const down = 105.0, up = 155.0;
  final _front = _Smooth();
  bool _isDown = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final angles = <double>[];
    if (lm != null) {
      for (final s in _Side.values) {
        final h = _p(lm, _j('hip', s)), k = _p(lm, _j('knee', s)), a = _p(lm, _j('ankle', s));
        if (h != null && k != null && a != null) angles.add(jointAngle(h, k, a));
      }
    }
    visible = angles.length == 2;
    if (!visible) {
      hint = 'Stand sideways so both legs are visible';
      return false;
    }
    hint = null;
    final front = _front.add(math.min(angles[0], angles[1]));
    final back = math.max(angles[0], angles[1]);
    motion = _ramp(front, 170, down);
    if (!_isDown && front < down && back < 145) {
      _isDown = true;
    } else if (_isDown && front > up && back > up) {
      _isDown = false;
      return countRep(now);
    }
    return false;
  }
}

/// Every knee lift up to around hip height counts as one rep.
class HighKneesCounter extends RepCounter {
  final _up = {_Side.left: false, _Side.right: false};

  @override
  bool update(Landmarks? lm, Duration now) {
    final ls = lm == null ? null : _p(lm, PoseLandmarkType.leftShoulder);
    final lh = lm == null ? null : _p(lm, PoseLandmarkType.leftHip);
    final rh = lm == null ? null : _p(lm, PoseLandmarkType.rightHip);
    final lk = lm == null ? null : _p(lm, PoseLandmarkType.leftKnee);
    final rk = lm == null ? null : _p(lm, PoseLandmarkType.rightKnee);
    visible = ![ls, lh, rh, lk, rk].contains(null);
    if (!visible) {
      hint = notVisibleHint;
      return false;
    }
    hint = null;
    final torso = math.max(_dist(ls!, lh!), 1.0);
    final hipY = (lh.y + rh!.y) / 2;
    var counted = false;
    var best = 0.0;
    for (final (side, knee) in [(_Side.left, lk!), (_Side.right, rk!)]) {
      // 0 when the knee hangs at rest (~0.9 torso below the hip), 1 at hip height.
      final lift = _ramp(knee.y - hipY, torso * 0.9, torso * 0.15);
      best = math.max(best, lift);
      if (!_up[side]! && lift > 0.85) {
        _up[side] = true;
        counted = countRep(now) || counted;
      } else if (_up[side]! && lift < 0.4) {
        _up[side] = false;
      }
    }
    motion = best;
    return counted;
  }
}

/// Accumulates seconds only while the body is held straight and horizontal.
class PlankTimer extends RepCounter {
  double seconds = 0;
  Duration? _last;
  bool holding = false;

  @override
  int get progress => seconds.floor();

  @override
  bool update(Landmarks? lm, Duration now) {
    final dt = _last == null ? Duration.zero : now - _last!;
    _last = now;
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'hip', 'ankle']);
    visible = pts != null;
    holding = false;
    if (pts == null) {
      hint = 'Place the phone to your side so your whole body is visible';
      return false;
    }
    final straight = jointAngle(pts['shoulder']!, pts['hip']!, pts['ankle']!);
    final horizontal = _tilt(pts['shoulder']!, pts['ankle']!) < 35;
    if (!horizontal) {
      hint = 'Get into plank position';
    } else if (straight < 155) {
      hint = pts['hip']!.y < (pts['shoulder']!.y + pts['ankle']!.y) / 2 ? 'Lower your hips' : 'Lift your hips';
    } else {
      hint = null;
      holding = true;
      // Cap the step so a dropped frame doesn't hand out free seconds.
      final before = seconds.floor();
      seconds += math.min(dt.inMicroseconds / 1e6, 0.5);
      motion = 1;
      return seconds.floor() > before;
    }
    motion = 0;
    return false;
  }
}

/// Elbow flexion on either arm: a rep when a curled arm (below ~55°)
/// straightens again (past ~145°). Alternating arms each count; both arms
/// curling together count once, since the second lands inside [minRepGap].
class BicepCurlCounter extends RepCounter {
  static const curled = 55.0, extended = 145.0;
  final _smooth = {_Side.left: _Smooth(), _Side.right: _Smooth()};
  final _isCurled = {_Side.left: false, _Side.right: false};

  @override
  bool update(Landmarks? lm, Duration now) {
    final angles = <_Side, double>{};
    if (lm != null) {
      for (final s in _Side.values) {
        final sh = _p(lm, _j('shoulder', s)), el = _p(lm, _j('elbow', s)), wr = _p(lm, _j('wrist', s));
        if (sh != null && el != null && wr != null) angles[s] = _smooth[s]!.add(jointAngle(sh, el, wr));
      }
    }
    visible = angles.isNotEmpty;
    if (!visible) {
      hint = 'Face the phone so your arms are visible';
      return false;
    }
    hint = null;
    motion = angles.values.map((a) => _ramp(a, 160, curled)).reduce(math.max);
    var counted = false;
    for (final MapEntry(key: side, value: a) in angles.entries) {
      if (!_isCurled[side]! && a < curled) {
        _isCurled[side] = true;
      } else if (_isCurled[side]! && a > extended) {
        _isCurled[side] = false;
        counted = countRep(now) || counted;
      }
    }
    return counted;
  }
}

/// Bench/chair dips, side view: elbows bend below ~100° then extend past ~150°.
class TricepDipCounter extends RepCounter {
  static const down = 100.0, up = 150.0;
  final _elbow = _Smooth();
  bool _isDown = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'elbow', 'wrist', 'hip']);
    visible = pts != null;
    if (pts == null) {
      hint = 'Sit side-on to the phone so your arm and hip are visible';
      return false;
    }
    if (pts['wrist']!.y < pts['shoulder']!.y) {
      hint = 'Place your hands on the edge behind you';
      return false;
    }
    hint = null;
    final elbow = _elbow.add(jointAngle(pts['shoulder']!, pts['elbow']!, pts['wrist']!));
    motion = _ramp(elbow, 165, down);
    if (!_isDown && elbow < down) {
      _isDown = true;
    } else if (_isDown && elbow > up) {
      _isDown = false;
      return countRep(now);
    }
    return false;
  }
}

/// Facing the camera: from hands at shoulder height (elbows bent) to both
/// arms straight overhead. Counted at the top.
class ShoulderPressCounter extends RepCounter {
  bool _ready = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final pts = <_Side, (PoseLandmark, PoseLandmark, PoseLandmark)>{};
    if (lm != null) {
      for (final s in _Side.values) {
        final sh = _p(lm, _j('shoulder', s)), el = _p(lm, _j('elbow', s)), wr = _p(lm, _j('wrist', s));
        if (sh != null && el != null && wr != null) pts[s] = (sh, el, wr);
      }
    }
    visible = pts.length == 2;
    if (!visible) {
      hint = 'Face the phone so both arms are visible';
      return false;
    }
    hint = null;
    final arms = pts.values.toList();
    final upperArm = math.max(_dist(arms[0].$1, arms[0].$2), 1.0);
    // 0 with wrists at shoulder height, 1 with wrists a full arm above it.
    final lift = arms.map((a) => _ramp(a.$1.y - a.$3.y, 0, upperArm * 1.8)).reduce(math.min);
    final straight = arms.every((a) => jointAngle(a.$1, a.$2, a.$3) > 150);
    final bent = arms.every((a) => jointAngle(a.$1, a.$2, a.$3) < 110);
    motion = lift;
    if (!_ready && bent && lift < 0.5) {
      _ready = true;
    } else if (_ready && straight && lift > 0.85) {
      _ready = false;
      return countRep(now);
    }
    return false;
  }
}

/// Facing the camera: both arms raised out to the side (shoulder angle past
/// ~75°) and lowered again (below ~30°).
class LateralRaiseCounter extends RepCounter {
  static const top = 75.0, bottom = 30.0;
  bool _isUp = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final angles = <double>[];
    if (lm != null) {
      for (final s in _Side.values) {
        final h = _p(lm, _j('hip', s)), sh = _p(lm, _j('shoulder', s)), el = _p(lm, _j('elbow', s));
        if (h != null && sh != null && el != null) angles.add(jointAngle(h, sh, el));
      }
    }
    visible = angles.length == 2;
    if (!visible) {
      hint = 'Face the phone so both arms and hips are visible';
      return false;
    }
    final low = math.min(angles[0], angles[1]);
    motion = _ramp(low, 15, top);
    hint = (angles[0] - angles[1]).abs() > 35 ? 'Raise both arms together' : null;
    if (!_isUp && low > top) {
      _isUp = true;
    } else if (_isUp && math.max(angles[0], angles[1]) < bottom) {
      _isUp = false;
      return countRep(now);
    }
    return false;
  }
}

/// Side view, lying with knees bent: the hip angle (shoulder–hip–knee) closes
/// below ~70° at the top of the sit-up and opens past ~115° lying down.
class SitUpCounter extends RepCounter {
  static const upAngle = 70.0, downAngle = 115.0;
  final _hip = _Smooth();
  bool _isUp = false;
  bool _wasDown = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'hip', 'knee']);
    visible = pts != null;
    if (pts == null) {
      hint = 'Lie side-on to the phone so your shoulders, hips and knees are visible';
      return false;
    }
    hint = null;
    final hip = _hip.add(jointAngle(pts['shoulder']!, pts['hip']!, pts['knee']!));
    motion = _ramp(hip, 130, upAngle);
    if (hip > downAngle) {
      _wasDown = true;
      _isUp = false;
    } else if (_wasDown && !_isUp && hip < upAngle) {
      _isUp = true;
      _wasDown = false;
      return countRep(now);
    }
    return false;
  }
}

/// Side view, lying on the back: hips drop (shoulder–hip–knee below ~145°)
/// then lift until the body is straight (past ~165°). Counted at the top.
class GluteBridgeCounter extends RepCounter {
  static const down = 145.0, up = 165.0;
  final _hip = _Smooth();
  bool _isDown = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'hip', 'knee']);
    visible = pts != null;
    if (pts == null) {
      hint = 'Lie side-on to the phone so your shoulders, hips and knees are visible';
      return false;
    }
    if (_tilt(pts['shoulder']!, pts['knee']!) > 50) {
      hint = 'Lie on your back with your knees bent';
      return false;
    }
    hint = null;
    final hip = _hip.add(jointAngle(pts['shoulder']!, pts['hip']!, pts['knee']!));
    motion = _ramp(hip, 130, up);
    if (!_isDown && hip < down) {
      _isDown = true;
    } else if (_isDown && hip > up) {
      _isDown = false;
      return countRep(now);
    }
    return false;
  }
}

/// Plank position, side view: each knee driven towards the chest (hip angle
/// below ~100°) counts once it extends back (past ~150°).
class MountainClimberCounter extends RepCounter {
  static const tucked = 100.0, extended = 150.0;
  final _in = {_Side.left: false, _Side.right: false};

  @override
  bool update(Landmarks? lm, Duration now) {
    final shoulder = lm == null ? null : _bestSide(lm, ['shoulder', 'wrist']);
    final legs = <_Side, double>{};
    if (lm != null && shoulder != null) {
      for (final s in _Side.values) {
        final h = _p(lm, _j('hip', s)), k = _p(lm, _j('knee', s));
        if (h != null && k != null) legs[s] = jointAngle(shoulder['shoulder']!, h, k);
      }
    }
    visible = shoulder != null && legs.isNotEmpty;
    if (!visible) {
      hint = 'Place the phone to your side so your whole body is visible';
      return false;
    }
    if (shoulder!['wrist']!.y < shoulder['shoulder']!.y) {
      hint = 'Get into push-up position';
      return false;
    }
    hint = null;
    motion = legs.values.map((a) => _ramp(a, 170, tucked)).reduce(math.max);
    var counted = false;
    for (final MapEntry(key: side, value: a) in legs.entries) {
      if (!_in[side]! && a < tucked) {
        _in[side] = true;
      } else if (_in[side]! && a > extended) {
        _in[side] = false;
        counted = countRep(now) || counted;
      }
    }
    return counted;
  }
}

/// Seconds held with knees at roughly 90° (70–115°) and the back upright.
class WallSitTimer extends RepCounter {
  double seconds = 0;
  Duration? _last;
  bool holding = false;

  @override
  int get progress => seconds.floor();

  @override
  bool update(Landmarks? lm, Duration now) {
    final dt = _last == null ? Duration.zero : now - _last!;
    _last = now;
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'hip', 'knee', 'ankle']);
    visible = pts != null;
    holding = false;
    if (pts == null) {
      hint = 'Sit side-on to the phone so your whole body is visible';
      return false;
    }
    final knee = jointAngle(pts['hip']!, pts['knee']!, pts['ankle']!);
    final upright = _tilt(pts['hip']!, pts['shoulder']!) > 60;
    if (!upright) {
      hint = 'Keep your back against the wall';
    } else if (knee > 115) {
      hint = 'Slide down until your knees are at 90°';
    } else if (knee < 70) {
      hint = 'Come up a little — knees at 90°';
    } else {
      hint = null;
      holding = true;
      final before = seconds.floor();
      seconds += math.min(dt.inMicroseconds / 1e6, 0.5);
      motion = 1;
      return seconds.floor() > before;
    }
    motion = 0;
    return false;
  }
}

/// Side view: from standing to the floor (body horizontal) and back up to
/// standing tall. Counted on returning to standing.
class BurpeeCounter extends RepCounter {
  bool _wasDown = false;

  @override
  bool update(Landmarks? lm, Duration now) {
    final pts = lm == null ? null : _bestSide(lm, ['shoulder', 'hip', 'knee', 'ankle']);
    visible = pts != null;
    if (pts == null) {
      hint = 'Step back so your whole body is in the frame';
      return false;
    }
    hint = null;
    final body = _tilt(pts['ankle']!, pts['shoulder']!);
    final knee = jointAngle(pts['hip']!, pts['knee']!, pts['ankle']!);
    final hip = jointAngle(pts['shoulder']!, pts['hip']!, pts['knee']!);
    final standing = body > 70 && knee > 155 && hip > 155;
    // Both torso and legs flat, so a deep squat isn't mistaken for the floor.
    final floor = _tilt(pts['hip']!, pts['shoulder']!) < 35 && _tilt(pts['hip']!, pts['ankle']!) < 35;
    motion = _ramp(body, 85, 20);
    if (!_wasDown && floor) {
      _wasDown = true;
    } else if (_wasDown && standing) {
      _wasDown = false;
      return countRep(now);
    }
    return false;
  }
}
