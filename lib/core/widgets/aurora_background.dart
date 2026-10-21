import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Slowly drifting, heavily blurred colour blobs behind the content.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.colors = const [AppColors.primary, AppColors.accent, AppColors.water],
    this.intensity = 0.16,
  });

  final Widget child;
  final List<Color> colors;
  final double intensity;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.background)),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(painter: _AuroraPainter(_c.value, widget.colors, widget.intensity)),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.colors, this.intensity);

  final double t;
  final List<Color> colors;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final phase = t * math.pi * 2 + i * 2.1;
      final center = Offset(
        size.width * (0.5 + 0.38 * math.cos(phase * (i.isEven ? 1 : -1))),
        size.height * (0.18 + 0.12 * i + 0.06 * math.sin(phase)),
      );
      final radius = size.width * (0.55 + 0.1 * math.sin(phase + i));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: intensity),
            colors[i].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
