import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/arcs/arc_providers.dart';
import '../../features/arcs/domain/arc.dart';
import '../theme/app_colors.dart';

/// Page canvas shared by every screen, with the current arc's weather
/// drifting behind the content: snow, embers, sunlight or rain.
class PageBackground extends ConsumerWidget {
  const PageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effect = ref.watch(themeSeasonProvider).effect;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: ArcWeather(effect: effect)),
          child,
          // A few particles drift in front of the content too, so the
          // weather feels like it is falling over the whole screen.
          Positioned.fill(child: ArcWeather(effect: effect, foreground: true, count: 9)),
        ],
      ),
    );
  }
}

/// Looping particles for [effect]. Still when the system asks for reduced
/// motion.
class ArcWeather extends StatefulWidget {
  const ArcWeather({super.key, required this.effect, this.dark = false, this.foreground = false, this.count = 22});

  final ArcEffect effect;

  /// Drawn over the content: particles only, no glow or frost.
  final bool foreground;

  /// Light particles for dark cards.
  final bool dark;
  final int count;

  @override
  State<ArcWeather> createState() => _ArcWeatherState();
}

class _ArcWeatherState extends State<ArcWeather> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _WeatherPainter(
          widget.effect,
          _c,
          dark: widget.dark,
          foreground: widget.foreground,
          count: widget.count,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.effect, this.anim, {required this.dark, required this.foreground, required this.count})
    : super(repaint: anim);

  final ArcEffect effect;
  final Animation<double> anim;
  final bool dark;
  final bool foreground;
  final int count;

  /// Stable pseudo-random value in 0–1 for particle [i], channel [k].
  static double _r(int i, int k) {
    final x = math.sin(i * 127.1 + k * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Foreground particles use their own offsets so they don't trail the
    // ones behind.
    final t = (anim.value + (foreground ? 0.37 : 0)) % 1.0;
    switch (effect) {
      case ArcEffect.snow:
        _snow(canvas, size, t);
      case ArcEffect.embers:
        _embers(canvas, size, t);
      case ArcEffect.sun:
        _sun(canvas, size, t);
      case ArcEffect.rain:
        _rain(canvas, size, t);
    }
  }

  Color get _tint => dark ? Colors.white : AppColors.accent;

  void _snow(Canvas canvas, Size size, double t) {
    // A frosty glow along the top edge.
    if (!dark && !foreground) {
      canvas.drawRect(
        Offset.zero & Size(size.width, 160),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primarySoft, AppColors.primarySoft.withValues(alpha: 0)],
          ).createShader(Offset.zero & Size(size.width, 160)),
      );
    }
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final speed = 0.6 + _r(i, 1) * 0.8;
      final y = ((_r(i, 2) + t * speed * 2) % 1.0) * (size.height + 20) - 10;
      final sway = math.sin((t * 6 + _r(i, 3)) * math.pi * 2) * 10;
      final x = _r(i, 4) * size.width + sway;
      final radius = (foreground ? 2.0 : 1.4) + _r(i, 5) * 2.4;
      paint.color = _tint.withValues(alpha: dark ? 0.3 : 0.35 + _r(i, 6) * 0.2);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _embers(Canvas canvas, Size size, double t) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var i = 0; i < count; i++) {
      final speed = 0.5 + _r(i, 1) * 0.9;
      final p = (_r(i, 2) + t * speed * 2) % 1.0;
      final y = size.height + 10 - p * (size.height + 20);
      final x = _r(i, 4) * size.width + math.sin((t * 5 + _r(i, 3)) * math.pi * 2) * 14;
      final fade = math.sin(p * math.pi);
      paint.color = Color.lerp(AppColors.energy, AppColors.primary, _r(i, 5))!.withValues(alpha: 0.45 * fade);
      canvas.drawCircle(Offset(x, y), 1.2 + _r(i, 6) * 2, paint);
    }
  }

  void _sun(Canvas canvas, Size size, double t) {
    if (foreground) {
      _motes(canvas, size, t);
      return;
    }
    final center = Offset(size.width * 0.95, -20);
    final pulse = 0.9 + 0.1 * math.sin(t * math.pi * 8);
    final r = size.width * 0.75 * pulse;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.energyLight.withValues(alpha: dark ? 0.25 : 0.45),
            AppColors.energyLight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    _motes(canvas, size, t);
  }

  /// Floating specks of sunlight.
  void _motes(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (var i = 0; i < count ~/ 2; i++) {
      final p = (_r(i, 2) + t * (0.3 + _r(i, 1) * 0.4)) % 1.0;
      final x = _r(i, 4) * size.width + math.sin((t * 4 + _r(i, 3)) * math.pi * 2) * 20;
      final y = size.height * (1 - p);
      paint.color = (dark ? Colors.white : AppColors.energy).withValues(alpha: 0.25 * math.sin(p * math.pi));
      canvas.drawCircle(Offset(x, y), 1.5 + _r(i, 5) * 2.5, paint);
    }
  }

  /// Lightning: a flicker near 12 %, 55 % and 83 % of the cycle (about every
  /// 8 seconds), each a quick double flash.
  static double _flash(double t) {
    double bump(double at, double w) {
      final d = (t - at).abs();
      return d >= w ? 0 : 1 - d / w;
    }

    return math.max(
      math.max(bump(0.120, 0.006), bump(0.134, 0.004) * 0.7),
      math.max(math.max(bump(0.550, 0.006), bump(0.563, 0.004) * 0.7), bump(0.830, 0.005)),
    );
  }

  void _rain(Canvas canvas, Size size, double t) {
    final flash = _flash(t);
    if (foreground) {
      // A brief brightening over everything, like a flash behind the clouds.
      if (flash > 0 && !dark) {
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEAF0FF).withValues(alpha: 0.30 * flash));
      }
    } else if (!dark) {
      // Heavy cloud bank across the top.
      final rect = Offset.zero & Size(size.width, 200);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary.withValues(alpha: 0.22), AppColors.primary.withValues(alpha: 0)],
          ).createShader(rect),
      );
      if (flash > 0.2) _bolt(canvas, size, flash);
    }
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = foreground ? 1.8 : 1.4;
    final n = foreground ? count : count + 26;
    for (var i = 0; i < n; i++) {
      final speed = 3.5 + _r(i, 1) * 2.5;
      final y = ((_r(i, 2) + t * speed * 2) % 1.0) * (size.height + 40) - 20;
      final x = _r(i, 4) * (size.width + 60) - (y / size.height) * 36;
      final len = 12 + _r(i, 5) * 12;
      paint.color = (dark ? Colors.white : AppColors.primary).withValues(
        alpha: dark ? 0.32 : (foreground ? 0.26 : 0.2),
      );
      canvas.drawLine(Offset(x, y), Offset(x - len * 0.3, y + len), paint);
    }
    if (!foreground && !dark) {
      // Ripples spreading on puddles along the bottom edge.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (var i = 0; i < 6; i++) {
        final p = (_r(i, 7) + t * (4 + i % 3)) % 1.0;
        final cx = _r(i, 8) * size.width;
        final cy = size.height - 10 - _r(i, 9) * 40;
        ring.color = AppColors.primary.withValues(alpha: 0.25 * (1 - p));
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 8 + p * 46, height: 3 + p * 14), ring);
      }
    }
  }

  /// A jagged lightning bolt from the top of the screen.
  void _bolt(Canvas canvas, Size size, double flash) {
    final x0 = size.width * (0.2 + 0.6 * _r((flash * 10).floor(), 11));
    final pts = <Offset>[Offset(x0, 0)];
    var x = x0, y = 0.0;
    for (var i = 0; i < 6; i++) {
      x += (i.isEven ? 1 : -1) * (14 + _r(i, 12) * 22);
      y += 24 + _r(i, 13) * 20;
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = AppColors.energy.withValues(alpha: 0.35 * flash)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.9 * flash),
    );
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.effect != effect || old.dark != dark || old.foreground != foreground || old.count != count;
}
