import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/arcs/arc_providers.dart';
import '../../features/arcs/domain/arc.dart';

/// The Fittarc logo in the look of the current season: ice and snow in
/// Winter, cherry blossom in Rise of Revolution, a sun in Summer, rain and storm in
/// Thunder Arc (artwork in `assets/logos`). The plain lime-on-black version is the
/// launcher and Play Store icon; this is what the app shows when it opens.
///
/// [progress] plays the opening (the logo rises in, then a light sweeps over
/// it and the season's effect starts); 1 shows the finished logo. With
/// [alive] the effect and the sweep keep looping.
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
    final p = widget.progress;
    final rise = Curves.easeOutBack.transform((p / 0.55).clamp(0.0, 1.0));
    final radius = BorderRadius.circular(size * 0.2);
    final tile = AnimatedBuilder(
      animation: _life,
      builder: (context, _) => Opacity(
        opacity: (p / 0.3).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.8 + 0.2 * rise,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: season.logoGlow.withValues(alpha: 0.35 * p),
                  blurRadius: size * 0.35,
                  spreadRadius: -size * 0.1,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/logos/${season.name}.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                  CustomPaint(
                    painter: _LogoEffects(season: season, progress: p, life: widget.alive ? _life.value : 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return widget.heroTag == null ? tile : Hero(tag: widget.heroTag!, child: tile);
  }
}

extension on Season {
  Color get logoGlow => switch (this) {
    Season.winter => const Color(0xFF5FB2E6),
    Season.spring => const Color(0xFFF06292),
    Season.summer => const Color(0xFFF2A51F),
    Season.monsoon => const Color(0xFF3FA0EA),
  };
}

/// The season's weather over the artwork, plus a sweep of light.
class _LogoEffects extends CustomPainter {
  _LogoEffects({required this.season, required this.progress, required this.life});

  final Season season;
  final double progress;
  final double life; // 0–1 through the 6 s idle loop

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final e = Curves.easeOut.transform(((progress - 0.5) / 0.5).clamp(0.0, 1.0));
    final dot = Paint();

    // One sweep of light as the logo finishes, and again each loop.
    final sweepT = progress < 1 ? ((progress - 0.55) / 0.4) : (life < 0.25 ? life / 0.25 : -1.0);
    if (sweepT > 0 && sweepT < 1) {
      final x = -0.4 * w + sweepT * 1.8 * w;
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.translate(x, 0);
      canvas.skew(-0.4, 0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w * 0.14, w),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w * 0.14, w)),
      );
      canvas.restore();
    }
    if (e <= 0) return;

    switch (season) {
      case Season.winter:
        for (var i = 0; i < 14; i++) {
          final x = ((i * 0.37 + 0.11) % 1) * w;
          final y = (((i * 0.23) + life * (1 + (i % 3) * 0.5)) % 1) * w;
          canvas.drawCircle(
            Offset(x, y),
            w * (0.005 + (i % 3) * 0.003),
            dot..color = Colors.white.withValues(alpha: 0.7 * e),
          );
        }
      case Season.spring:
        for (var i = 0; i < 10; i++) {
          final x = ((i * 0.31 + 0.07) % 1) * w;
          final rise = (life * (1 + (i % 3) * 0.4) + i * 0.17) % 1;
          canvas.drawCircle(
            Offset(x, w * (1 - rise)),
            w * 0.008 * (1 - rise),
            dot..color = const Color(0xFFFFB3CC).withValues(alpha: 0.9 * (1 - rise) * e),
          );
        }
      case Season.summer:
        for (var i = 0; i < 5; i++) {
          final c = Offset(((i * 0.41 + 0.2) % 1) * w, ((i * 0.29 + 0.12) % 0.6) * w);
          final tw = math.max(0.0, math.sin((life * 3 + i * 0.37) * 2 * math.pi));
          final r = w * 0.02 * tw;
          final star = Paint()
            ..color = const Color(0xFFFFEBA6).withValues(alpha: 0.9 * tw * e)
            ..strokeWidth = w * 0.006
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), star);
          canvas.drawLine(c.translate(0, -r), c.translate(0, r), star);
        }
      case Season.monsoon:
        final rain = Paint()
          ..color = const Color(0xFFB4E8FF).withValues(alpha: 0.45 * e)
          ..strokeWidth = w * 0.005
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 14; i++) {
          final x = ((i * 0.29 + 0.05) % 1) * w;
          final y = ((i * 0.41 + life * (4 + (i % 3))) % 1) * w * 1.1;
          canvas.drawLine(Offset(x, y), Offset(x - w * 0.015, y + w * 0.06), rain);
        }
        final f = math.max(_flash(life, 0.10), _flash(life, 0.18));
        if (f > 0) canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.22 * f));
    }
  }

  static double _flash(double t, double at) {
    final d = (t - at).abs();
    return d > 0.02 ? 0 : 1 - d / 0.02;
  }

  @override
  bool shouldRepaint(_LogoEffects old) => old.season != season || old.progress != progress || old.life != life;
}
