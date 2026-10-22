import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/exercise.dart';
import 'move_demos.dart';

/// A looping stick-figure animation of how to do [exercise], with the phone
/// drawn where it should be placed (in front, or on the floor to the side).
class ExerciseDemo extends StatefulWidget {
  ExerciseDemo({super.key, required Exercise exercise, this.height = 170, this.dark = false})
    : demoId = exercise.name,
      label = exercise.label,
      showPhone = true;

  /// A guided move (no camera), so no phone is drawn.
  const ExerciseDemo.move({super.key, required this.demoId, required this.label, this.height = 170, this.dark = false})
    : showPhone = false;

  /// Key into the demo table: an [Exercise] name or a move id.
  final String demoId;
  final String label;
  final double height;
  final bool showPhone;

  /// Light strokes for use over the camera preview.
  final bool dark;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: demoFor(widget.demoId).cycle)
    ..repeat();

  @override
  void didUpdateWidget(ExerciseDemo old) {
    super.didUpdateWidget(old);
    if (old.demoId != widget.demoId) {
      _c.duration = demoFor(widget.demoId).cycle;
      _c
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demo = demoFor(widget.demoId);
    return Semantics(
      label: 'Animation showing how to do ${widget.label}',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _DemoPainter(demo, _c.value, dark: widget.dark, phone: widget.showPhone),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ model

/// Joint positions in a 100×100 box (y down). "f" = far side, drawn lighter.
typedef Pose = Map<String, Offset>;

enum DemoView { front, side }

class DemoSpec {
  const DemoSpec(this.view, this.frames, {this.cycle = const Duration(milliseconds: 1800), this.prop});

  final DemoView view;
  final List<Pose> frames;
  final Duration cycle;

  /// Extra scenery: 'wall', 'bench' (under the hands) or 'step' (under the
  /// feet).
  final String? prop;
}

Offset _go(Offset from, double len, double deg) =>
    from + Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180)) * len;

/// Front view. Arm angles are measured from straight down, positive away from
/// the body (180 = straight up). [crouch] 0–1 bends the knees; [lift] raises a
/// knee to hip height. [hop] lifts the feet off the ground; every frame of a
/// demo that hops must pass it (0 when on the ground).
Pose frontPose({
  double crouch = 0,
  double spread = 0,
  double upL = 12,
  double foreL = 12,
  double upR = 12,
  double foreR = 12,
  double liftL = 0,
  double liftR = 0,
  double? hop,
}) {
  final drop = 14 * crouch;
  final p = <String, Offset>{};
  p['head'] = Offset(50, 16 + drop);
  p['neck'] = Offset(50, 24 + drop);
  for (final (side, sign, up, fore, lift) in [('L', -1.0, upL, foreL, liftL), ('R', 1.0, upR, foreR, liftR)]) {
    final sh = Offset(50 + sign * 7, 26 + drop);
    Offset arm(Offset from, double len, double a) =>
        from + Offset(sign * math.sin(a * math.pi / 180), math.cos(a * math.pi / 180)) * len;
    final el = arm(sh, 12, up);
    p['sh$side'] = sh;
    p['el$side'] = el;
    p['wr$side'] = arm(el, 11, fore);
    final hip = Offset(50 + sign * 5, 50 + drop);
    final ankle = Offset(50 + sign * (5 + 9 * spread), 86);
    var knee = Offset((hip.dx + ankle.dx) / 2 + sign * 5 * crouch, 68 + drop * 0.45);
    var foot = ankle;
    if (lift > 0) {
      knee = Offset.lerp(knee, Offset(hip.dx, hip.dy - 2), lift)!;
      foot = Offset.lerp(ankle, Offset(hip.dx, hip.dy + 16), lift)!;
    }
    p['hip$side'] = hip;
    p['kn$side'] = knee;
    p['an$side'] = foot;
  }
  if (hop != null) {
    for (final e in p.entries.toList()) {
      p[e.key] = e.value - Offset(0, hop);
    }
    p['gnd'] = const Offset(50, 86);
  }
  return p;
}

/// Side view, facing right. Angles are absolute directions in degrees
/// (0 = right, 90 = down, 180 = left, 270 = up). The far leg/arm default to
/// the near ones.
Pose sidePose({
  required double torso,
  required double thigh,
  required double shin,
  double upper = 90,
  double fore = 90,
  double? thighF,
  double? shinF,
  double? upperF,
  double? foreF,
}) {
  const hip = Offset(50, 50);
  final sh = _go(hip, 25, torso);
  final p = <String, Offset>{'hip': hip, 'sh': sh};
  p['neck'] = _go(hip, 29, torso);
  p['head'] = _go(hip, 35, torso);
  p['kn'] = _go(hip, 17, thigh);
  p['an'] = _go(p['kn']!, 17, shin);
  p['knf'] = _go(hip, 17, thighF ?? thigh);
  p['anf'] = _go(p['knf']!, 17, shinF ?? shin);
  p['el'] = _go(sh, 12, upper);
  p['wr'] = _go(p['el']!, 11, fore);
  p['elf'] = _go(sh, 12, upperF ?? upper);
  p['wrf'] = _go(p['elf']!, 11, foreF ?? fore);
  return p;
}

final Map<String, DemoSpec> _exerciseDemos = {
  'squat': DemoSpec(DemoView.front, [
    frontPose(upL: 70, foreL: 85, upR: 70, foreR: 85),
    frontPose(crouch: 1, upL: 80, foreL: 90, upR: 80, foreR: 90),
  ]),
  'jumpingJack': DemoSpec(DemoView.front, [
    frontPose(),
    frontPose(spread: 1, upL: 160, foreL: 170, upR: 160, foreR: 170),
  ], cycle: const Duration(milliseconds: 1100)),
  'highKnees': DemoSpec(DemoView.front, [
    frontPose(liftL: 1, upL: 30, foreL: 140, upR: 20, foreR: 20),
    frontPose(liftR: 1, upR: 30, foreR: 140, upL: 20, foreL: 20),
  ], cycle: const Duration(milliseconds: 900)),
  'bicepCurl': DemoSpec(DemoView.front, [
    frontPose(upL: 8, foreL: 8, upR: 8, foreR: 8),
    frontPose(upL: 8, foreL: 165, upR: 8, foreR: 165),
  ]),
  'shoulderPress': DemoSpec(DemoView.front, [
    frontPose(upL: 85, foreL: 175, upR: 85, foreR: 175),
    frontPose(upL: 168, foreL: 175, upR: 168, foreR: 175),
  ]),
  'lateralRaise': DemoSpec(DemoView.front, [
    frontPose(upL: 12, foreL: 14, upR: 12, foreR: 14),
    frontPose(upL: 88, foreL: 90, upR: 88, foreR: 90),
  ]),
  'pushUp': DemoSpec(DemoView.side, [
    sidePose(torso: 192, thigh: 4, shin: 4, upper: 90, fore: 90),
    sidePose(torso: 184, thigh: 1, shin: 1, upper: 40, fore: 135),
  ]),
  'kneePushUp': DemoSpec(DemoView.side, [
    sidePose(torso: 200, thigh: 30, shin: -20, upper: 90, fore: 90),
    sidePose(torso: 190, thigh: 18, shin: -30, upper: 40, fore: 135),
  ]),
  'plank': DemoSpec(DemoView.side, [
    sidePose(torso: 186, thigh: 3, shin: 3, upper: 90, fore: 180),
    sidePose(torso: 186.5, thigh: 3.5, shin: 3.5, upper: 90, fore: 180),
  ], cycle: const Duration(milliseconds: 2400)),
  'sitUp': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: -45, shin: 45, upper: 5, fore: 0),
    sidePose(torso: 245, thigh: -45, shin: 45, upper: -30, fore: -30),
  ]),
  'gluteBridge': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: -48, shin: 55, upper: 10, fore: 0),
    sidePose(torso: 163, thigh: -12, shin: 80, upper: 28, fore: 0),
  ]),
  'mountainClimber': DemoSpec(DemoView.side, [
    sidePose(torso: 192, thigh: 140, shin: 50, thighF: 4, shinF: 4, upper: 90, fore: 90),
    sidePose(torso: 192, thigh: 4, shin: 4, thighF: 140, shinF: 50, upper: 90, fore: 90),
  ], cycle: const Duration(milliseconds: 1000)),
  'tricepDip': DemoSpec(DemoView.side, [
    sidePose(torso: 272, thigh: 0, shin: 85, upper: 100, fore: 92),
    sidePose(torso: 268, thigh: -8, shin: 75, upper: 140, fore: 60),
  ], prop: 'bench'),
  'wallSit': DemoSpec(
    DemoView.side,
    [
      sidePose(torso: 270, thigh: 0, shin: 90, upper: 70, fore: 20),
      sidePose(torso: 270.5, thigh: 0.5, shin: 90, upper: 71, fore: 21),
    ],
    cycle: const Duration(milliseconds: 2400),
    prop: 'wall',
  ),
  'lunge': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 95, shin: 90, thighF: 85, shinF: 90),
    sidePose(torso: 270, thigh: 5, shin: 90, thighF: 115, shinF: 178),
  ]),
  'burpee': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 90, fore: 90),
    sidePose(torso: 225, thigh: -30, shin: 110, upper: 70, fore: 90),
    sidePose(torso: 192, thigh: 4, shin: 4, upper: 90, fore: 90),
    sidePose(torso: 225, thigh: -30, shin: 110, upper: 70, fore: 90),
    sidePose(torso: 270, thigh: 92, shin: 90, upper: 255, fore: 265),
  ], cycle: const Duration(milliseconds: 3200)),
};

/// The demo for an [Exercise] name or a guided move id.
DemoSpec demoFor(String id) => _exerciseDemos[id] ?? moveDemos[id] ?? _exerciseDemos['squat']!;

// ---------------------------------------------------------------- painter

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.demo, this.t, {required this.dark, required this.phone});

  final DemoSpec demo;
  final double t;
  final bool dark;
  final bool phone;

  static const ground = 88.0;

  /// The current pose: ease between consecutive keyframes, looping.
  Pose _pose() {
    final frames = demo.frames;
    final n = frames.length;
    final pos = t * n;
    final i = pos.floor() % n;
    final local = Curves.easeInOut.transform(pos - pos.floor());
    final a = frames[i], b = frames[(i + 1) % n];
    return {for (final k in a.keys) k: Offset.lerp(a[k], b[k], local)!};
  }

  @override
  void paint(Canvas canvas, Size size) {
    var pose = _pose();
    // Stand the figure on the ground and centre it, leaving room for the phone.
    final maxY = pose.values.map((o) => o.dy).reduce(math.max);
    final xs = [
      for (final e in pose.entries)
        if (e.key != 'gnd') e.value.dx,
    ];
    final cx = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
    // Without the phone the figure gets the whole, narrower box (bigger).
    final boxW = phone ? 130.0 : 96.0;
    final shift = Offset((phone ? 58 : boxW / 2) - cx, ground - 1.5 - maxY);
    pose = {for (final e in pose.entries) e.key: e.value + shift};

    final scale = math.min(size.width / boxW, size.height / 100);
    canvas.save();
    canvas.translate((size.width - boxW * scale) / 2, (size.height - 100 * scale) / 2);
    canvas.scale(scale);

    final ink = dark ? Colors.white : AppColors.primary;
    final faint = dark ? Colors.white54 : AppColors.accent.withValues(alpha: 0.55);
    final line = dark ? Colors.white38 : AppColors.stroke;

    // Ground and props.
    canvas.drawLine(
      const Offset(4, ground),
      Offset(boxW - 4, ground),
      Paint()
        ..color = line
        ..strokeWidth = 1.2,
    );
    if (demo.prop == 'wall') {
      final x = pose['sh']!.dx - 4;
      canvas.drawRect(Rect.fromLTWH(x - 3, 10, 3, ground - 10), Paint()..color = line);
    } else if (demo.prop == 'bench' || demo.prop == 'step') {
      final w = pose[demo.prop == 'bench' ? 'wr' : 'an']!;
      final top = w.dy + 1;
      final bench = Paint()..color = line;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w.dx - 14, top, 20, 3), const Radius.circular(1)), bench);
      canvas.drawRect(Rect.fromLTWH(w.dx - 12, top, 2, ground - top), bench);
      canvas.drawRect(Rect.fromLTWH(w.dx + 2, top, 2, ground - top), bench);
    }

    if (phone) _phone(canvas, ink, line);

    final near = Paint()
      ..color = ink
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final far = Paint()
      ..color = faint
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void limb(List<String> keys, Paint p) {
      final path = Path()..moveTo(pose[keys.first]!.dx, pose[keys.first]!.dy);
      for (final k in keys.skip(1)) {
        path.lineTo(pose[k]!.dx, pose[k]!.dy);
      }
      canvas.drawPath(path, p);
    }

    if (demo.view == DemoView.front) {
      limb(['shL', 'elL', 'wrL'], near);
      limb(['shR', 'elR', 'wrR'], near);
      limb(['hipL', 'knL', 'anL'], near);
      limb(['hipR', 'knR', 'anR'], near);
      limb(['shL', 'shR'], near);
      limb(['hipL', 'hipR'], near);
      final midSh = (pose['shL']! + pose['shR']!) / 2, midHip = (pose['hipL']! + pose['hipR']!) / 2;
      canvas.drawLine(midSh, midHip, near);
      canvas.drawLine(pose['neck']!, midSh, near);
    } else {
      limb(['sh', 'elf', 'wrf'], far);
      limb(['hip', 'knf', 'anf'], far);
      limb(['hip', 'sh', 'neck'], near);
      limb(['hip', 'kn', 'an'], near);
      limb(['sh', 'el', 'wr'], near);
    }
    canvas.drawCircle(pose['head']!, 5.2, Paint()..color = ink);
    canvas.restore();
  }

  /// Phone placement: standing in front for front-view exercises, lying on
  /// the floor to the side for side-view ones.
  void _phone(Canvas canvas, Color ink, Color line) {
    final body = Paint()..color = ink.withValues(alpha: 0.85);
    final screen = Paint()..color = dark ? Colors.black45 : Colors.white;
    if (demo.view == DemoView.front) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(8, ground - 22, 11, 20), const Radius.circular(2.5));
      canvas.drawRRect(r, body);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(9.5, ground - 20, 8, 15), const Radius.circular(1.5)),
        screen,
      );
      // Small stand.
      canvas.drawLine(
        Offset(13.5, ground - 2),
        Offset(13.5, ground),
        Paint()
          ..color = ink
          ..strokeWidth = 1.5,
      );
    } else {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(6, ground - 9, 18, 7), const Radius.circular(2));
      canvas.drawRRect(r, body);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(7.5, ground - 7.8, 12, 4.6), const Radius.circular(1)),
        screen,
      );
    }
    // Dashed line of sight.
    final dash = Paint()
      ..color = line
      ..strokeWidth = 1;
    final y = demo.view == DemoView.front ? ground - 14 : ground - 6;
    for (var x = 26.0; x < 38; x += 4) {
      canvas.drawLine(Offset(x, y), Offset(x + 2, y), dash);
    }
  }

  @override
  bool shouldRepaint(_DemoPainter old) => old.t != t || old.demo != demo || old.dark != dark || old.phone != phone;
}

/// One line on where to put the phone, for under the animation.
String phonePlacement(Exercise e) => demoFor(e.name).view == DemoView.front
    ? 'Phone upright in front of you, about 2 m away'
    : 'Phone on the floor to your side, about 2 m away';

/// Bottom sheet with the animation, phone placement and tips for [e].
Future<void> showExerciseHowTo(BuildContext context, Exercise e) {
  final text = Theme.of(context).textTheme;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(e.label, style: text.titleLarge),
            Text(e.muscles, style: text.bodySmall),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
              child: ExerciseDemo(exercise: e, height: 190),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(phonePlacement(e), style: text.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            Text(e.tip, style: text.bodyMedium?.copyWith(height: 1.45)),
          ],
        ),
      ),
    ),
  );
}
