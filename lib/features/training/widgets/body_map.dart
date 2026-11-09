import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/muscles.dart';

/// A front and back body figure with the worked muscles highlighted.
class BodyMap extends StatelessWidget {
  const BodyMap({super.key, required this.muscles, this.height = 200, this.showLegend = true});

  final Set<Muscle> muscles;
  final double height;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Body map. Works: ${muscles.map((m) => m.label).join(', ')}',
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final back in [false, true])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 100 / 200,
                            child: CustomPaint(
                              painter: _BodyPainter(
                                muscles: muscles,
                                back: back,
                                body: AppColors.surfaceHigh,
                                outline: AppColors.stroke,
                                on: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Text(back ? 'Back' : 'Front', style: text.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (showLegend && muscles.isNotEmpty && muscles.length < Muscle.values.length) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final m in muscles)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                    child: Text(m.label, style: text.labelMedium?.copyWith(color: AppColors.primary)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Draws a simple figure on a 100 × 200 grid, mirrored left and right.
class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.muscles,
    required this.back,
    required this.body,
    required this.outline,
    required this.on,
  });

  final Set<Muscle> muscles;
  final bool back;
  final Color body, outline, on;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 200);
    final base = Paint()..color = body;
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    void shape(Path p, [Paint? fill]) {
      canvas.drawPath(p, fill ?? base);
      canvas.drawPath(p, line);
    }

    RRect r(double l, double t, double w, double h, [double rad = 6]) =>
        RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(rad));
    Path rr(double l, double t, double w, double h, [double rad = 6]) => Path()..addRRect(r(l, t, w, h, rad));
    Path oval(double l, double t, double w, double h) => Path()..addOval(Rect.fromLTWH(l, t, w, h));

    // Silhouette.
    shape(oval(40, 4, 20, 24)); // head
    shape(rr(45, 26, 10, 8, 3)); // neck
    shape(rr(30, 33, 40, 62, 12)); // torso
    for (final x in [16.0, 74.0]) {
      shape(rr(x, 38, 10, 34, 5)); // upper arm
      shape(rr(x - 2, 72, 10, 30, 5)); // forearm
    }
    for (final x in [33.0, 51.0]) {
      shape(rr(x, 94, 16, 54, 8)); // thigh
      shape(rr(x + 1, 148, 13, 44, 6)); // lower leg
    }

    final hit = Paint()..color = on;
    void m(Muscle muscle, Iterable<Path> parts) {
      if (!muscles.contains(muscle)) return;
      for (final p in parts) {
        shape(p, hit);
      }
    }

    // Shoulders on both views.
    m(Muscle.shoulders, [oval(24, 33, 13, 12), oval(63, 33, 13, 12)]);
    if (!back) {
      m(Muscle.chest, [rr(33, 40, 16, 15, 5), rr(51, 40, 16, 15, 5)]);
      m(Muscle.biceps, [rr(17, 46, 8, 22, 4), rr(75, 46, 8, 22, 4)]);
      m(Muscle.forearms, [rr(15, 74, 8, 24, 4), rr(77, 74, 8, 24, 4)]);
      m(Muscle.abs, [rr(42, 57, 16, 33, 4)]);
      m(Muscle.obliques, [rr(33, 59, 8, 28, 4), rr(59, 59, 8, 28, 4)]);
      m(Muscle.hipFlexors, [rr(37, 88, 8, 8, 3), rr(55, 88, 8, 8, 3)]);
      m(Muscle.quads, [rr(35, 100, 12, 42, 6), rr(53, 100, 12, 42, 6)]);
      m(Muscle.innerThighs, [rr(45, 100, 4, 26, 2), rr(51, 100, 4, 26, 2)]);
      m(Muscle.calves, [rr(36, 154, 9, 30, 4), rr(55, 154, 9, 30, 4)]);
    } else {
      m(Muscle.upperBack, [rr(34, 37, 32, 24, 6)]);
      m(Muscle.lowerBack, [rr(40, 63, 20, 24, 5)]);
      m(Muscle.triceps, [rr(17, 44, 8, 24, 4), rr(75, 44, 8, 24, 4)]);
      m(Muscle.forearms, [rr(15, 74, 8, 24, 4), rr(77, 74, 8, 24, 4)]);
      m(Muscle.glutes, [oval(33, 86, 17, 16), oval(50, 86, 17, 16)]);
      m(Muscle.hamstrings, [rr(35, 104, 12, 40, 6), rr(53, 104, 12, 40, 6)]);
      m(Muscle.calves, [rr(35, 150, 11, 30, 5), rr(54, 150, 11, 30, 5)]);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.muscles != muscles || old.back != back || old.on != on;
}
