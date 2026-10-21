import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'film_grain.dart';

/// Cinematic golden-hour sunrise: the sky warms from linen to peach, the sun
/// rises behind layered salmon hills, rays turn, a lens flare drifts along
/// the light axis, birds cross, and the whole frame slowly pushes in (a Ken
/// Burns move) under fine film grain.
class SunriseScene extends StatefulWidget {
  const SunriseScene({super.key});

  @override
  State<SunriseScene> createState() => _SunriseSceneState();
}

class _SunriseSceneState extends State<SunriseScene> with TickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(seconds: 6))..forward();
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  late final _push = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat(reverse: true);

  @override
  void dispose() {
    _rise.dispose();
    _loop.dispose();
    _push.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_rise, _loop, _push]),
          builder: (_, _) => Transform.scale(
            scale: 1 + 0.06 * Curves.easeInOut.transform(_push.value),
            alignment: const Alignment(0, 0.2),
            child: CustomPaint(
              size: Size.infinite,
              painter: _SunrisePainter(rise: Curves.easeOutCubic.transform(_rise.value), t: _loop.value),
            ),
          ),
        ),
      ),
      const FilmGrain(),
    ],
  );
}

class _SunrisePainter extends CustomPainter {
  _SunrisePainter({required this.rise, required this.t});

  final double rise;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Sky: pre-dawn linen warming through pale to peach at the horizon.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFFF1EEE4), AppColors.linen, rise)!,
            Color.lerp(const Color(0xFFF3E2D6), AppColors.pale, rise)!,
            Color.lerp(const Color(0xFFF0C6B2), AppColors.peach, rise)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    final horizon = h * 0.62;
    final sunR = w * 0.2;
    final sun = Offset(w / 2, horizon + sunR * 1.4 - rise * sunR * 2.4);
    final pulse = 1 + 0.03 * math.sin(t * math.pi * 2 * 6);

    // Atmospheric glow.
    canvas.drawCircle(
      sun,
      sunR * 3.4 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.candyCorn.withValues(alpha: 0.55 * rise),
            AppColors.peach.withValues(alpha: 0.25 * rise),
            AppColors.peach.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR * 3.4)),
    );

    // God rays.
    final ray = Paint()..color = Colors.white.withValues(alpha: 0.18 * rise);
    for (var i = 0; i < 12; i++) {
      final a = t * math.pi * 2 + i * math.pi / 6;
      final path = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(a - 0.07) * sunR * 4.5, sun.dy + math.sin(a - 0.07) * sunR * 4.5)
        ..lineTo(sun.dx + math.cos(a + 0.07) * sunR * 4.5, sun.dy + math.sin(a + 0.07) * sunR * 4.5)
        ..close();
      canvas.drawPath(path, ray);
    }

    // Sun disc: candy-corn core into salmon rim.
    canvas.drawCircle(
      sun,
      sunR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF6D6), AppColors.candyCorn, AppColors.salmon],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR)),
    );

    // Lens flare: ghosts strung along the line from the sun through the
    // frame centre, drifting as the sun moves.
    final centre = Offset(w / 2 + math.sin(t * math.pi * 2) * w * 0.08, h * 0.42);
    final axis = centre - sun;
    for (final (k, r, c) in [
      (0.6, 0.18, AppColors.candyCorn),
      (1.1, 0.08, AppColors.salmon),
      (1.5, 0.28, AppColors.peach),
      (1.9, 0.05, Colors.white),
    ]) {
      final p = sun + axis * k;
      canvas.drawCircle(
        p,
        sunR * r,
        Paint()
          ..color = c.withValues(alpha: 0.22 * rise)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sunR * r * 0.4),
      );
    }

    // Birds.
    final bird = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5 * rise)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = ((t * 1.5 + i * 0.27) % 1.2 - 0.1) * w;
      final y = h * (0.3 + i * 0.04) + math.sin(t * 20 + i) * 4;
      final flap = 4 + 2 * math.sin(t * 90 + i * 2);
      canvas.drawPath(
        Path()
          ..moveTo(x - 7, y - flap)
          ..quadraticBezierTo(x - 3, y - 1, x, y)
          ..quadraticBezierTo(x + 3, y - 1, x + 7, y - flap),
        bird,
      );
    }

    // Layered hills with aerial perspective: far ones hazy, near ones richer.
    void hill(double base, double amp, double phase, Color color) {
      final path = Path()..moveTo(0, h);
      double y(double x) => base + math.sin(x / w * math.pi * 2 + phase + t * math.pi * 2) * amp;
      for (var x = 0.0; x < w; x += 6) {
        path.lineTo(x, y(x));
      }
      path
        ..lineTo(w, y(w))
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    hill(horizon + 10, 14, 0.3, const Color(0xFFF6CDB4));
    hill(horizon + 48, 18, 2.1, const Color(0xFFEFA48C));
    hill(horizon + 92, 12, 4.0, AppColors.linen);

    // Soft vignette to focus the eye, like a lens.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, const Color(0xFF8A4A36).withValues(alpha: 0.10)],
          stops: const [0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SunrisePainter old) => old.rise != rise || old.t != t;
}
