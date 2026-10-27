import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arcs/domain/arc.dart';

/// The light look of each season on the opening screen.
class SeasonLook {
  const SeasonLook({
    required this.top,
    required this.bottom,
    required this.markLight,
    required this.markMid,
    required this.markDeep,
    required this.accent,
  });

  /// Background gradient (always light).
  final Color top;
  final Color bottom;

  /// The three tones the logo mark is shaded with.
  final Color markLight;
  final Color markMid;
  final Color markDeep;

  /// Weather and highlight colour.
  final Color accent;

  /// The neutral light colour the launch screen uses before this fades in.
  static const launch = Color(0xFFF4F8FD);

  static SeasonLook of(Season s) => switch (s) {
    Season.winter => const SeasonLook(
      top: Color(0xFFF6FAFF),
      bottom: Color(0xFFD9E9F9),
      markLight: Color(0xFFB8EAFF),
      markMid: Color(0xFF5DBBF5),
      markDeep: Color(0xFF2F78C8),
      accent: Color(0xFF8DBDEB),
    ),
    Season.spring => const SeasonLook(
      top: Color(0xFFFFF8FA),
      bottom: Color(0xFFFADCE7),
      markLight: Color(0xFFFFC2D6),
      markMid: Color(0xFFF06292),
      markDeep: Color(0xFFC2346E),
      accent: Color(0xFFF48FB1),
    ),
    Season.summer => const SeasonLook(
      top: Color(0xFFFFFAF0),
      bottom: Color(0xFFFCE4BE),
      markLight: Color(0xFFFFE08A),
      markMid: Color(0xFFF7AE22),
      markDeep: Color(0xFFD9701C),
      accent: Color(0xFFF2A51F),
    ),
    Season.monsoon => const SeasonLook(
      top: Color(0xFFF3F6FB),
      bottom: Color(0xFFD3DDEC),
      markLight: Color(0xFFB4D2FF),
      markMid: Color(0xFF5B8FE0),
      markDeep: Color(0xFF3A55B0),
      accent: Color(0xFF6E8BB8),
    ),
  };
}

/// Season weather over the whole screen: snow, blossom petals, golden light
/// or rain with soft lightning. Drawn for a light background.
class SeasonWeatherPainter extends CustomPainter {
  SeasonWeatherPainter({required this.season, required this.seconds, required this.intensity});

  final Season season;

  /// Time since the weather started.
  final double seconds;

  /// 0–1: how much of the weather has arrived.
  final double intensity;

  static double _r(int i, int k) => (math.sin(i * 12.9898 + k * 78.233) * 43758.5453).abs() % 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final look = SeasonLook.of(season);
    switch (season) {
      case Season.winter:
        _snow(canvas, size, look);
      case Season.spring:
        _petals(canvas, size, look);
      case Season.summer:
        _sun(canvas, size, look);
      case Season.monsoon:
        _rain(canvas, size, look);
    }
  }

  void _snow(Canvas canvas, Size size, SeasonLook look) {
    final count = (90 * intensity).round();
    for (var i = 0; i < count; i++) {
      final depth = _r(i, 1); // far (small, slow) to near (big, fast)
      final speed = 28 + depth * 70;
      final r = 1.6 + depth * 4.2;
      final x0 = _r(i, 2) * size.width;
      final y = ((_r(i, 3) * size.height) + seconds * speed) % (size.height + 20) - 10;
      final x = x0 + math.sin(seconds * (0.6 + depth) + i) * (10 + depth * 16);
      final blur = depth > 0.7 ? 1.6 : 0.0;
      final paint = Paint()
        ..color = Color.lerp(look.accent, const Color(0xFFFFFFFF), 0.25)!.withValues(alpha: 0.35 + depth * 0.5)
        ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;
      canvas.drawCircle(Offset(x, y), r, paint);
      // A tiny bright core so flakes read on a light background.
      canvas.drawCircle(
        Offset(x - r * 0.25, y - r * 0.25),
        r * 0.45,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _petals(Canvas canvas, Size size, SeasonLook look) {
    final count = (46 * intensity).round();
    for (var i = 0; i < count; i++) {
      final depth = _r(i, 1);
      final speed = 22 + depth * 46;
      final w = 6 + depth * 9;
      final y = ((_r(i, 3) * size.height) + seconds * speed) % (size.height + 30) - 15;
      final x = _r(i, 2) * size.width + math.sin(seconds * 0.9 + i) * (16 + depth * 20) + seconds * 6 * depth;
      final c = Color.lerp(const Color(0xFFFFC2D6), look.accent, _r(i, 5))!;
      canvas.save();
      canvas.translate(x % (size.width + 20), y);
      canvas.rotate(seconds * (0.8 + depth) + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.5),
        Paint()..color = c.withValues(alpha: 0.5 + depth * 0.4),
      );
      canvas.restore();
    }
  }

  void _sun(Canvas canvas, Size size, SeasonLook look) {
    // Soft sun and slow rays from the top-right corner.
    final c = Offset(size.width * 0.92, size.height * 0.04);
    final glow = size.width * (0.9 + 0.04 * math.sin(seconds * 1.4));
    canvas.drawCircle(
      c,
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE9A8).withValues(alpha: 0.85 * intensity),
            const Color(0xFFFFE9A8).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glow)),
    );
    final ray = Paint()
      ..color = const Color(0xFFFFD36A).withValues(alpha: 0.14 * intensity)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = math.pi * 0.5 + i * math.pi / 14 + seconds * 0.05;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * 90,
        c + Offset(math.cos(a), math.sin(a)) * size.height * 0.9,
        ray,
      );
    }
    // Drifting golden sparkles.
    final count = (36 * intensity).round();
    for (var i = 0; i < count; i++) {
      final depth = _r(i, 1);
      final y = size.height - (((_r(i, 3) * size.height) + seconds * (14 + depth * 26)) % size.height);
      final x = _r(i, 2) * size.width + math.sin(seconds * 0.7 + i) * 12;
      final tw = 0.5 + 0.5 * math.sin(seconds * 2.2 + i * 1.7);
      canvas.drawCircle(
        Offset(x, y),
        1.6 + depth * 2.6,
        Paint()..color = look.accent.withValues(alpha: (0.25 + 0.5 * tw) * intensity),
      );
    }
  }

  void _rain(Canvas canvas, Size size, SeasonLook look) {
    final count = (80 * intensity).round();
    for (var i = 0; i < count; i++) {
      final depth = _r(i, 1);
      final speed = 420 + depth * 520;
      final len = 14 + depth * 26;
      final y = ((_r(i, 3) * size.height) + seconds * speed) % (size.height + 60) - 30;
      final x = (_r(i, 2) * size.width + y * 0.22) % (size.width + 40);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - len * 0.22, y + len),
        Paint()
          ..color = look.accent.withValues(alpha: 0.18 + depth * 0.32)
          ..strokeWidth = 1 + depth * 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    // Soft lightning: two quick flashes, then a third later.
    double flash(double at) => math.max(0, 1 - (seconds - at).abs() / 0.09);
    final f = math.max(flash(1.15), math.max(flash(1.4), flash(3.4))) * intensity;
    if (f > 0) canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.55 * f));
  }

  @override
  bool shouldRepaint(SeasonWeatherPainter old) =>
      old.seconds != seconds || old.intensity != intensity || old.season != season;
}

/// The FittArc mark drawn straight onto the background (no tile): three
/// pieces that slide in, shaded in the season's colours.
class BrandMarkPainter extends CustomPainter {
  BrandMarkPainter({required this.look, required this.progress, required this.shine});

  final SeasonLook look;

  /// 0–1: the blocks arrive.
  final double progress;

  /// 0–1: a band of light crossing the finished mark (null-ish when 0 or 1).
  final double shine;

  static const _blocks = <List<List<Offset>>>[
    [
      [Offset(560.9, 467.7), Offset(577.4, 482), Offset(628, 531.2), Offset(629.9, 388.2), Offset(865.7, 388.2), Offset(913, 386.8), Offset(848.7, 316), Offset(561.8, 316), Offset(560.4, 318.8)],
    ],
    [
      [Offset(788, 436), Offset(645.9, 436.4), Offset(646.4, 569.3), Offset(645, 575.3), Offset(588.9, 527), Offset(588.9, 609.3), Offset(636.7, 656.7), Offset(700.2, 725.6), Offset(700.6, 492.5), Offset(749.8, 491.2)],
    ],
    [
      [Offset(837.2, 398.8), Offset(787.5, 472.3), Offset(718.1, 567.9), Offset(718.6, 686.5), Offset(743.9, 653), Offset(837.6, 519.2), Offset(925.5, 656.7), Offset(974.2, 726.5), Offset(975.1, 598.3), Offset(880.9, 458.1)],
      [Offset(781.1, 636), Offset(893.3, 636), Offset(857.9, 579.4), Offset(854.7, 579), Offset(817, 579.4)],
    ],
  ];
  static const _from = [Offset(-170, -70), Offset(-60, 190), Offset(170, 30)];
  static const _centre = Offset(768, 521.5);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / 411;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    canvas.translate(-_centre.dx, -_centre.dy);
    final paths = <Path>[];
    for (var i = 0; i < _blocks.length; i++) {
      final t = Curves.easeOutCubic.transform(((progress - i * 0.14) / 0.6).clamp(0.0, 1.0));
      if (t <= 0) continue;
      final path = Path();
      for (final poly in _blocks[i]) {
        path.addPolygon([for (final p in poly) p + _from[i] * (1 - t)], true);
      }
      paths.add(path);
      final b = path.getBounds();
      // A soft shadow so the mark sits on the light background.
      canvas.drawPath(
        path.shift(const Offset(0, 14)),
        Paint()
          ..color = look.markDeep.withValues(alpha: 0.28 * t)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [look.markLight, look.markMid, look.markDeep],
          ).createShader(b)
          ..color = Colors.white.withValues(alpha: t),
      );
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTWH(b.left, b.top, b.width, b.height * 0.4),
        Paint()..color = Colors.white.withValues(alpha: 0.22 * t),
      );
      canvas.restore();
    }
    if (shine > 0 && shine < 1 && paths.length == 3) {
      final x = 560 + shine * 560;
      canvas.save();
      canvas.clipPath(paths.fold(Path(), (a, b) => Path.combine(PathOperation.union, a, b)));
      canvas.translate(x, 0);
      canvas.skew(-0.35, 0);
      canvas.drawRect(
        const Rect.fromLTWH(-60, 280, 120, 480),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.65),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(const Rect.fromLTWH(-60, 280, 120, 480)),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.progress != progress || old.shine != shine || old.look != look;
}
