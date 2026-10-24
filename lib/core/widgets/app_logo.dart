import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/arcs/arc_providers.dart';
import '../../features/arcs/domain/arc.dart';

/// The FittiePi mark in the look of the current season: the angular F on a
/// dark tile, with ice and snow in Winter, embers in Revolution, sun and
/// glow in Summer, rain and lightning in Monsoon. The Play Store icon is the
/// plain lime version; this is what the opening screen shows.
///
/// [progress] assembles the mark (its three blocks slide in, then the season
/// effect arrives); 1 shows the finished logo. With [alive] the effect keeps
/// playing. The shapes are traced from the master logo.
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
    final look = LogoLook.of(season);
    final size = widget.size;
    final tile = AnimatedBuilder(
      animation: _life,
      builder: (context, _) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(
            color: look.mid.withValues(alpha: 0.45 * widget.progress),
            width: size * 0.012,
          ),
          boxShadow: [
            BoxShadow(
              color: look.mid.withValues(alpha: 0.30 * widget.progress),
              blurRadius: size * 0.3,
              spreadRadius: -size * 0.08,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: CustomPaint(
            painter: LogoMarkPainter(
              season: season,
              look: look,
              progress: widget.progress,
              life: widget.alive ? _life.value : 0,
            ),
          ),
        ),
      ),
    );
    return widget.heroTag == null ? tile : Hero(tag: widget.heroTag!, child: tile);
  }
}

/// Colours of the mark for one season.
class LogoLook {
  const LogoLook(this.bgTop, this.bgBottom, this.light, this.mid, this.deep);

  final Color bgTop;
  final Color bgBottom;
  final Color light;
  final Color mid;
  final Color deep;

  static LogoLook of(Season s) => switch (s) {
    Season.winter => const LogoLook(
      Color(0xFF0E2340),
      Color(0xFF060F1E),
      Color(0xFFF2FAFF),
      Color(0xFF6CC3F2),
      Color(0xFF2F78C0),
    ),
    Season.revolution => const LogoLook(
      Color(0xFF3A1512),
      Color(0xFF1A0908),
      Color(0xFFFFE2A8),
      Color(0xFFF08A35),
      Color(0xFFB23A2B),
    ),
    Season.summer => const LogoLook(
      Color(0xFF3A2208),
      Color(0xFF1A1004),
      Color(0xFFFFEBA6),
      Color(0xFFF7AE22),
      Color(0xFFD9701C),
    ),
    Season.monsoon => const LogoLook(
      Color(0xFF16213C),
      Color(0xFF080C18),
      Color(0xFFB4E8FF),
      Color(0xFF3FA0EA),
      Color(0xFF4A5D96),
    ),
  };
}

/// Paints the mark and the season's effect on a square canvas.
class LogoMarkPainter extends CustomPainter {
  LogoMarkPainter({required this.season, required this.look, required this.progress, required this.life});

  final Season season;
  final LogoLook look;
  final double progress;

  /// 0–1 through the 6 s idle loop.
  final double life;

  // Traced from the master logo (source space 1536×1024); the mark is centred
  // on (768, 521.5) and 346×411.
  static const _blocks = <List<Offset>>[
    [Offset(595, 316), Offset(863, 316), Offset(941, 397), Offset(675, 397), Offset(675, 518), Offset(595, 433)],
    [
      Offset(703, 467),
      Offset(839, 467),
      Offset(839, 545),
      Offset(759, 545),
      Offset(759, 727),
      Offset(668, 635),
      Offset(668, 527),
      Offset(703, 562),
    ],
    [Offset(817, 414), Offset(885, 414), Offset(932, 467), Offset(932, 560), Offset(851, 627), Offset(851, 467)],
  ];
  // Where each block slides in from, in source units.
  static const _from = [Offset(-150, -60), Offset(-60, 170), Offset(150, 20)];
  static const _centre = Offset(768, 521.5);

  double _phase(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((progress - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [look.bgTop, look.bgBottom],
        ).createShader(Offset.zero & size),
    );
    final effect = _phase(0.55, 1, Curves.easeOut);
    _backdrop(canvas, size, effect);

    // The mark fills ~58% of the tile height.
    final k = w * 0.58 / 411;
    canvas.save();
    canvas.translate(w / 2, w / 2);
    canvas.scale(k);
    canvas.translate(-_centre.dx, -_centre.dy);
    for (var i = 0; i < _blocks.length; i++) {
      final t = _phase(0.05 + i * 0.12, 0.5 + i * 0.12);
      if (t <= 0) continue;
      final path = Path()..addPolygon([for (final p in _blocks[i]) p + _from[i] * (1 - t)], true);
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [look.light, look.mid, look.deep],
          ).createShader(bounds)
          ..color = Colors.white.withValues(alpha: t),
      );
      // A facet of light along the top edge.
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height * 0.34),
        Paint()..color = Colors.white.withValues(alpha: 0.22 * t),
      );
      canvas.restore();
    }
    canvas.restore();
    _foreground(canvas, size, effect);
  }

  /// Glow and weather behind the mark.
  void _backdrop(Canvas canvas, Size size, double e) {
    if (e <= 0) return;
    final w = size.width;
    switch (season) {
      case Season.summer:
        final pulse = 1 + 0.06 * math.sin(life * 2 * math.pi * 3);
        final c = Offset(w * 0.8, w * 0.2);
        canvas.drawCircle(
          c,
          w * 0.3 * pulse * e,
          Paint()
            ..shader = RadialGradient(colors: [look.light.withValues(alpha: 0.75), look.mid.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: w * 0.3 * pulse)),
        );
        canvas.drawCircle(c, w * 0.075 * e, Paint()..color = look.light);
      case Season.revolution:
        final glow = Offset(w / 2, w * 0.95);
        canvas.drawCircle(
          glow,
          w * 0.6,
          Paint()
            ..shader = RadialGradient(
              colors: [
                look.deep.withValues(alpha: 0.55 * e),
                look.deep.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: glow, radius: w * 0.6)),
        );
      case Season.monsoon:
        final f = math.max(_flash(life, 0.10), _flash(life, 0.18));
        if (f > 0) canvas.drawRect(Offset.zero & size, Paint()..color = look.light.withValues(alpha: 0.28 * f));
      case Season.winter:
        break;
    }
  }

  /// Falling snow, rising embers, rain or sun rays, over the mark.
  void _foreground(Canvas canvas, Size size, double e) {
    if (e <= 0) return;
    final w = size.width;
    final p = Paint()..color = look.light;
    switch (season) {
      case Season.winter:
        for (var i = 0; i < 14; i++) {
          final x = ((i * 0.37 + 0.11) % 1) * w;
          final y = (((i * 0.23) + life * (1 + (i % 3) * 0.5)) % 1) * w;
          canvas.drawCircle(
            Offset(x, y),
            w * (0.006 + (i % 3) * 0.004),
            p..color = look.light.withValues(alpha: 0.75 * e),
          );
        }
        // A small snowflake in the top-left corner.
        canvas.save();
        canvas.translate(w * 0.2, w * 0.24);
        canvas.rotate(life * 2 * math.pi / 3);
        final line = Paint()
          ..color = look.light.withValues(alpha: e)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.014;
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          final d = Offset(math.cos(a), math.sin(a)) * w * 0.075;
          canvas.drawLine(-d, d, line);
        }
        canvas.restore();
      case Season.revolution:
        for (var i = 0; i < 12; i++) {
          final x = ((i * 0.31 + 0.07) % 1) * w;
          final rise = (life * (1 + (i % 3) * 0.4) + i * 0.17) % 1;
          canvas.drawCircle(
            Offset(x, w * (1 - rise)),
            w * 0.008 * (1 - rise),
            p..color = look.light.withValues(alpha: 0.9 * (1 - rise) * e),
          );
        }
      case Season.summer:
        final c = Offset(w * 0.8, w * 0.2);
        final ray = Paint()
          ..color = look.light.withValues(alpha: 0.8 * e)
          ..strokeWidth = w * 0.012
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 10; i++) {
          final a = life * 2 * math.pi / 10 + i * 2 * math.pi / 10;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * w * 0.1, c + d * w * 0.13, ray);
        }
      case Season.monsoon:
        final rain = Paint()
          ..color = look.light.withValues(alpha: 0.55 * e)
          ..strokeWidth = w * 0.006
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 16; i++) {
          final x = ((i * 0.29 + 0.05) % 1) * w;
          final y = ((i * 0.41 + life * (4 + (i % 3))) % 1) * w * 1.1;
          canvas.drawLine(Offset(x, y), Offset(x - w * 0.015, y + w * 0.06), rain);
        }
    }
  }

  static double _flash(double t, double at) {
    final d = (t - at).abs();
    return d > 0.02 ? 0 : 1 - d / 0.02;
  }

  @override
  bool shouldRepaint(LogoMarkPainter old) => old.season != season || old.progress != progress || old.life != life;
}
