import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Brand mark: a light-brown tile with a white alarm clock and check.
///
/// [progress] draws the white mark on (ring, then bell ears, then check) for
/// the opening animation; 1 shows the finished logo. The geometry matches the
/// Android launch assets in `android/app/src/main/res`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88, this.progress = 1, this.heroTag = 'app-logo'});

  final double size;
  final double progress;

  /// Lets the logo fly between the splash and sign-in screens.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25 * progress),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
            spreadRadius: -size * 0.1,
          ),
        ],
      ),
      child: CustomPaint(painter: _MarkPainter(progress)),
    );
    return heroTag == null ? tile : Hero(tag: heroTag!, child: tile);
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.progress);

  final double progress;

  static const _ring = (0.5, 0.56, 0.22);
  static const _stroke = 0.062;
  static const _ears = [((0.29, 0.32), (0.36, 0.25)), ((0.71, 0.32), (0.64, 0.25))];
  static const _check = [(0.41, 0.56), (0.475, 0.625), (0.6, 0.5)];

  double _phase(double from, double to) =>
      Curves.easeInOutCubic.transform(((progress - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p((double, double) v) => Offset(v.$1 * s, v.$2 * s);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Ring sweeps round from the top.
    final ring = _phase(0, 0.55);
    if (ring > 0) {
      final rect = Rect.fromCircle(center: p((_ring.$1, _ring.$2)), radius: _ring.$3 * s);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * ring, false, paint);
    }

    // Bell ears grow outward from the clock.
    final ears = _phase(0.35, 0.7);
    if (ears > 0) {
      for (final (a, b) in _ears) {
        canvas.drawLine(p(a), Offset.lerp(p(a), p(b), ears)!, paint);
      }
    }

    // Check mark is drawn along its path.
    final check = _phase(0.55, 1);
    if (check > 0) {
      final path = Path()
        ..moveTo(p(_check[0]).dx, p(_check[0]).dy)
        ..lineTo(p(_check[1]).dx, p(_check[1]).dy)
        ..lineTo(p(_check[2]).dx, p(_check[2]).dy);
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * check), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.progress != progress;
}
