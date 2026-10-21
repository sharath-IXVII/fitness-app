import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder brand mark: a sun rising over a horizon inside a caramel
/// squircle — the "wake up and move" idea in one glyph.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.12),
            spreadRadius: -size * 0.12,
          ),
        ],
      ),
      child: CustomPaint(painter: _SunMarkPainter()),
    );
  }
}

class _SunMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final horizon = s * 0.64;
    final center = Offset(s / 2, horizon);
    final r = s * 0.2;
    final white = Paint()..color = Colors.white;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, s, horizon));
    canvas.drawCircle(center, r, white);
    canvas.restore();

    final ray = Paint()
      ..color = AppColors.gold
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = math.pi + math.pi * (i + 1) / 6;
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * (r * 1.45),
        center + Offset(math.cos(a), math.sin(a)) * (r * 1.95),
        ray,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s / 2, horizon + s * 0.03), width: s * 0.62, height: s * 0.06),
        Radius.circular(s * 0.03),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s / 2, horizon + s * 0.13), width: s * 0.36, height: s * 0.05),
        Radius.circular(s * 0.025),
      ),
      white..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_SunMarkPainter oldDelegate) => false;
}
