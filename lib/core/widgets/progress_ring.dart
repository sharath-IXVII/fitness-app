import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated circular progress with a gradient sweep and a glowing tip.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.secondaryColor,
    this.child,
  });

  final double progress;
  final Color color;
  final Color? secondaryColor;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: value,
            color: color,
            secondary: secondaryColor ?? Color.lerp(color, Colors.white, 0.35)!,
            stroke: stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.secondary, required this.stroke});

  final double value;
  final Color color;
  final Color secondary;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep, 0.01),
        colors: [color, secondary],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arc);

    // Glowing dot at the leading edge.
    final angle = -math.pi / 2 + sweep;
    final r = arcRect.width / 2;
    final tip = rect.center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    canvas.drawCircle(
      tip,
      stroke * 0.9,
      Paint()
        ..color = secondary.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.stroke != stroke;
}
