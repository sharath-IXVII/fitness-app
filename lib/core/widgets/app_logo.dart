import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/arcs/arc_providers.dart';
import '../../features/arcs/domain/arc.dart';
import '../theme/app_colors.dart';

/// The FittiePi mark: a chunky F under a rising arc, with the season's symbol
/// at the arc's tip (snowflake, flame, sun or lightning). It is drawn in the
/// colours of the current arc and changes with it, exactly like the launcher
/// icon, which switches with the season too.
///
/// [progress] draws the mark on (the arc rises, the F strokes in, the symbol
/// pops) for the opening animation; 1 shows the finished logo. With [alive]
/// the symbol keeps moving: the snowflake turns, the flame flickers, the sun
/// spins, and the lightning flashes. The geometry matches the launcher icons
/// in `android/app/src/main/res/drawable-nodpi`.
class AppLogo extends ConsumerStatefulWidget {
  const AppLogo({super.key, this.size = 88, this.progress = 1, this.alive = false, this.heroTag = 'app-logo'});

  final double size;
  final double progress;
  final bool alive;

  /// Lets the logo fly between the splash and sign-in screens.
  final String? heroTag;

  @override
  ConsumerState<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends ConsumerState<AppLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.alive) _life.repeat();
  }

  @override
  void didUpdateWidget(AppLogo old) {
    super.didUpdateWidget(old);
    if (widget.alive && !_life.isAnimating) _life.repeat();
    if (!widget.alive && _life.isAnimating) _life.stop();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final season = ref.watch(themeSeasonProvider);
    final size = widget.size;
    final tile = AnimatedBuilder(
      animation: _life,
      builder: (context, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.ink],
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.28 * widget.progress),
              blurRadius: size * 0.3,
              offset: Offset(0, size * 0.1),
              spreadRadius: -size * 0.1,
            ),
          ],
        ),
        child: CustomPaint(
          painter: LogoMarkPainter(
            season: season,
            progress: widget.progress,
            life: widget.alive ? _life.value : 0,
            arc: AppColors.energy,
            light: AppColors.energyLight,
          ),
        ),
      ),
    );
    return widget.heroTag == null ? tile : Hero(tag: widget.heroTag!, child: tile);
  }
}

/// Paints the mark onto a 432-unit canvas scaled to the available size.
class LogoMarkPainter extends CustomPainter {
  LogoMarkPainter({
    required this.season,
    required this.progress,
    required this.life,
    required this.arc,
    required this.light,
  });

  final Season season;
  final double progress;

  /// 0–1 through the 6 s idle loop.
  final double life;
  final Color arc;
  final Color light;

  static const _tip = Offset(316, 254);

  double _phase(double from, double to, [Curve curve = Curves.easeInOutCubic]) =>
      curve.transform(((progress - from) / (to - from)).clamp(0.0, 1.0));

  void _partial(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 432;
    canvas.save();
    canvas.scale(k);
    canvas.translate(216, 225);
    canvas.scale(1.05);
    canvas.translate(-216, -225);

    final rise = Path()..moveTo(116, 254);
    rise.arcToPoint(_tip, radius: const Radius.circular(100));
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [arc, light],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(const Rect.fromLTWH(116, 154, 200, 100));
    _partial(canvas, rise, _phase(0, 0.5), arcPaint);

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _partial(
      canvas,
      Path()
        ..moveTo(186, 200)
        ..lineTo(186, 296),
      _phase(0.3, 0.6),
      white,
    );
    _partial(
      canvas,
      Path()
        ..moveTo(186, 200)
        ..lineTo(262, 200),
      _phase(0.5, 0.75),
      white,
    );
    _partial(
      canvas,
      Path()
        ..moveTo(186, 248)
        ..lineTo(244, 248),
      _phase(0.6, 0.82),
      white,
    );

    final pop = _phase(0.75, 1, Curves.easeOutBack);
    if (pop > 0) {
      canvas.save();
      canvas.translate(_tip.dx, _tip.dy);
      canvas.scale(pop);
      canvas.drawCircle(Offset.zero, 44, Paint()..color = AppColors.ink);
      canvas.drawCircle(
        Offset.zero,
        44,
        Paint()
          ..color = arc
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      canvas.scale(1.1);
      _glyph(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  /// The season's symbol, centred on the origin, about 60 units across.
  void _glyph(Canvas canvas) {
    final fill = Paint()..color = light;
    final line = Paint()
      ..color = light
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (season) {
      case Season.winter:
        canvas.rotate(life * 2 * math.pi / 3); // arms repeat every 60°, so a third turn loops cleanly
        line.strokeWidth = 8;
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(d * -26, d * 26, line);
          // Small side branches near each tip.
          for (final end in [-1.0, 1.0]) {
            final dir = d * end;
            for (final side in [-0.8, 0.8]) {
              final a2 = math.atan2(dir.dy, dir.dx) + side;
              final from = dir * 15;
              canvas.drawLine(from, from + Offset(math.cos(a2), math.sin(a2)) * 9, line..strokeWidth = 5);
            }
          }
          line.strokeWidth = 8;
        }
        canvas.drawCircle(Offset.zero, 5, fill);
      case Season.revolution:
        final flicker = 1 + 0.07 * math.sin(life * 2 * math.pi * 6) + 0.03 * math.sin(life * 2 * math.pi * 11);
        canvas.scale(1 / flicker, flicker);
        final flame = Path()
          ..moveTo(0, -32)
          ..cubicTo(6, -16, 22, -8, 22, 10)
          ..cubicTo(22, 23, 12, 32, 0, 32)
          ..cubicTo(-12, 32, -22, 23, -22, 10)
          ..cubicTo(-22, 0, -13, -6, -9, -18)
          ..cubicTo(-5, -12, -2, -8, 0, -32)
          ..close();
        canvas.drawPath(flame, fill);
        canvas.drawPath(
          Path()
            ..moveTo(0, 8)
            ..cubicTo(7, 15, 8, 22, 0, 27)
            ..cubicTo(-8, 22, -7, 15, 0, 8)
            ..close(),
          Paint()..color = arc,
        );
      case Season.summer:
        canvas.rotate(life * 2 * math.pi / 8);
        final pulse = 1 + 0.06 * math.sin(life * 2 * math.pi * 4);
        canvas.drawCircle(Offset.zero, 12 * pulse, fill);
        line.strokeWidth = 6;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(d * 20, d * 30, line);
        }
      case Season.monsoon:
        // A flash twice per loop: the bolt brightens, then fades.
        final f = math.max(_flash(life, 0.10), _flash(life, 0.18));
        final bolt = Path()
          ..moveTo(7, -32)
          ..lineTo(-15, 3)
          ..lineTo(-2, 3)
          ..lineTo(-9, 32)
          ..lineTo(17, -9)
          ..lineTo(3, -9)
          ..close();
        if (f > 0) canvas.drawCircle(Offset.zero, 38, Paint()..color = light.withValues(alpha: 0.35 * f));
        canvas.drawPath(bolt, fill);
    }
  }

  static double _flash(double t, double at) {
    final d = (t - at).abs();
    return d > 0.02 ? 0 : 1 - d / 0.02;
  }

  @override
  bool shouldRepaint(LogoMarkPainter old) =>
      old.season != season || old.progress != progress || old.life != life || old.arc != arc || old.light != light;
}
