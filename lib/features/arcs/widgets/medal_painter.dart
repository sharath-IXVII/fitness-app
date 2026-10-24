import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/arc.dart';

/// Two looks for the same badge: a frosted [glass] disc (the default) or a
/// metal-rimmed [hex].
enum MedalStyle { glass, hex }

/// Arc badges, drawn in code (vector, sharp at any size).
///
/// One polished hexagon for every badge, in the style of fitness awards:
///  - a brushed-metal rim (bronze, silver or gold) marks the tier,
///  - a deep, season-coloured face carries a clean line-art emblem
///    (snowflake, flame, sun, storm cloud),
///  - rank chevrons under the emblem count the tier (1, 2 or 3),
///  - gold badges get a rosette behind them and an animated glint.
class MedalPainter extends CustomPainter {
  MedalPainter({
    required this.season,
    required this.tier,
    this.earned = true,
    this.shine = 0,
    this.style = MedalStyle.glass,
  });

  final MedalStyle style;

  final Season season;
  final ArcTier tier;
  final bool earned;

  /// 0–1 position of the glint across the badge.
  final double shine;

  // Rim metals, light → dark, plus the deep edge colour.
  static const _bronze = [Color(0xFFF1C9A0), Color(0xFFC98A55), Color(0xFF8B5530), Color(0xFF4A2A14)];
  static const _silver = [Color(0xFFFFFFFF), Color(0xFFCBD3DE), Color(0xFF8593A6), Color(0xFF3E495B)];
  static const _gold = [Color(0xFFFFF1B5), Color(0xFFF2C14E), Color(0xFFB98A12), Color(0xFF5E4300)];

  List<Color> get _metal => !earned
      ? const [Color(0xFFF3F4F7), Color(0xFFD9DDE4), Color(0xFFB7BDC9), Color(0xFF8E96A6)]
      : switch (tier) {
          ArcTier.survivor => _bronze,
          ArcTier.warrior => _silver,
          ArcTier.master => _gold,
        };

  /// Face gradient: top (lighter) to bottom (deep).
  List<Color> get _face => !earned
      ? const [Color(0xFFF7F8FA), Color(0xFFE6E9EE)]
      : switch (season) {
          Season.winter => const [Color(0xFF3F86C8), Color(0xFF0B2342)],
          Season.spring => const [Color(0xFFE8588F), Color(0xFF4A0F2A)],
          Season.summer => const [Color(0xFFF7A12A), Color(0xFF7A2A05)],
          Season.monsoon => const [Color(0xFF5A6FBA), Color(0xFF0E1431)],
        };

  Color get _glow => switch (season) {
    Season.winter => const Color(0xFF8AD0FF),
    Season.spring => const Color(0xFFFF8FB8),
    Season.summer => const Color(0xFFFFD36A),
    Season.monsoon => const Color(0xFF9DB1FF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (style == MedalStyle.glass) return _paintGlass(canvas, size);
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 100);
    const c = Offset(50, 50);

    if (tier == ArcTier.master && earned) _rosette(canvas, c);

    final outer = _hex(c, 44, round: 6);
    // Soft drop shadow.
    if (earned) {
      canvas.drawPath(
        outer.shift(const Offset(0, 2.6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    // Brushed-metal rim: a sweep gradient with alternating light and dark.
    final m = _metal;
    canvas.drawPath(
      outer,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [m[1], m[0], m[1], m[2], m[1], m[0], m[2], m[1]],
          stops: const [0, 0.14, 0.3, 0.45, 0.6, 0.76, 0.9, 1],
          transform: const GradientRotation(-math.pi / 3),
        ).createShader(Rect.fromCircle(center: c, radius: 46)),
    );
    _stroke(canvas, outer, 1.4, m[3].withValues(alpha: earned ? 0.85 : 0.5));
    // Bevel: a light line just inside the rim, a dark one outside the face.
    final bevel = _hex(c, 40.5, round: 4.5);
    _stroke(canvas, bevel, 1.0, Colors.white.withValues(alpha: earned ? 0.55 : 0.5));

    final face = _hex(c, 38, round: 4);
    final fr = Rect.fromCircle(center: c, radius: 38);
    canvas.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _face,
        ).createShader(fr),
    );
    _stroke(canvas, face, 1.2, m[3].withValues(alpha: earned ? 0.7 : 0.4));

    canvas.save();
    canvas.clipPath(face);
    if (earned) {
      // Glow behind the emblem and a faint diagonal sheen.
      canvas.drawCircle(
        c + const Offset(0, -4),
        26,
        Paint()
          ..shader = RadialGradient(colors: [_glow.withValues(alpha: 0.55), _glow.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c + const Offset(0, -4), radius: 26)),
      );
    }
    _emblem(canvas, c + const Offset(0, -8), 0.8);
    _chevrons(canvas, c + const Offset(0, 27));
    _gloss(canvas, fr);
    canvas.restore();
    if (earned && shine > 0) _glint(canvas, outer);
    canvas.restore();
  }

  // ------------------------------------------------------------- glass

  /// A frosted-glass disc tinted by the season, ringed by three segments
  /// that light up in the tier's metal (one, two or three).
  void _paintGlass(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 100);
    const c = Offset(50, 50);
    final m = _metal;
    final body = Path()..addOval(Rect.fromCircle(center: c, radius: 36));
    final bodyRect = Rect.fromCircle(center: c, radius: 36);

    if (earned) {
      canvas.drawCircle(
        c + const Offset(0, 3.5),
        36,
        Paint()
          ..color = _face[1].withValues(alpha: 0.38)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
      );
    }
    // The glass itself: translucent, lighter at the top.
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: earned
              ? [_face[0].withValues(alpha: 0.80), _face[1].withValues(alpha: 0.92)]
              : [Colors.white.withValues(alpha: 0.85), const Color(0xFFE3E6EC).withValues(alpha: 0.9)],
        ).createShader(bodyRect),
    );

    canvas.save();
    canvas.clipPath(body);
    if (earned) {
      canvas.drawCircle(
        c + const Offset(0, -6),
        28,
        Paint()
          ..shader = RadialGradient(colors: [_glow.withValues(alpha: 0.6), _glow.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c + const Offset(0, -6), radius: 28)),
      );
      _decor(canvas, c);
    }
    _emblem(canvas, c + const Offset(0, -6), 0.78);
    _chevrons(canvas, c + const Offset(0, 24), scale: 0.8);
    if (earned) {
      // Curved highlight on the upper glass, and a thin reflection below.
      final hi = Path()..addOval(Rect.fromCenter(center: c + const Offset(0, -19), width: 62, height: 34));
      canvas.drawPath(
        hi,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.02)],
          ).createShader(hi.getBounds()),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 32),
        math.pi * 0.2,
        math.pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.28),
      );
    }
    canvas.restore();

    // Glass edge: bright at the top-left, fading to the bottom-right.
    canvas.drawCircle(
      c,
      36,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: earned ? 0.95 : 0.9),
            Colors.white.withValues(alpha: earned ? 0.12 : 0.3),
          ],
        ).createShader(bodyRect),
    );

    // Tier ring: three segments, lit in the tier's metal.
    const gap = 0.26;
    final seg = 2 * math.pi / 3 - gap;
    final ringRect = Rect.fromCircle(center: c, radius: 43);
    for (var i = 0; i < 3; i++) {
      final lit = earned && i <= tier.index;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: lit ? [m[0], m[1], m[2]] : [const Color(0xFFD5D9E1), const Color(0xFFBFC5D0)],
        ).createShader(ringRect);
      canvas.drawArc(ringRect, -math.pi / 2 + i * 2 * math.pi / 3 + gap / 2, seg, false, paint);
    }
    if (earned && shine > 0) _glint(canvas, body);
    canvas.restore();
  }

  /// Season detail inside the glass.
  void _decor(Canvas canvas, Offset c) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.5);
    switch (season) {
      case Season.winter:
        for (final o in const [Offset(-24, -14), Offset(22, -22), Offset(24, 12), Offset(-20, 18)]) {
          final q = c + o;
          final line = Paint()
            ..color = Colors.white.withValues(alpha: 0.65)
            ..strokeWidth = 1
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(q.translate(-2.5, 0), q.translate(2.5, 0), line);
          canvas.drawLine(q.translate(0, -2.5), q.translate(0, 2.5), line);
        }
      case Season.spring:
        for (final (o, a) in const [(Offset(-23, -16), 0.6), (Offset(24, 6), -0.5), (Offset(-14, 22), 1.0)]) {
          canvas.save();
          canvas.translate(c.dx + o.dx, c.dy + o.dy);
          canvas.rotate(a);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 4, height: 6.5), p);
          canvas.restore();
        }
      case Season.summer:
        final ray = Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final d = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(c + d * 20 + const Offset(0, -6), c + d * 34 + const Offset(0, -6), ray);
        }
      case Season.monsoon:
        final rain = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        for (final o in const [Offset(-26, -8), Offset(-18, 14), Offset(24, -14), Offset(20, 18), Offset(-6, 26)]) {
          final q = c + o;
          canvas.drawLine(q, q.translate(-2, 6), rain);
        }
    }
  }

  // ------------------------------------------------------------ shapes

  /// A pointy-top hexagon of [r] with softly rounded corners.
  Path _hex(Offset c, double r, {double round = 5}) {
    final pts = [
      for (var i = 0; i < 6; i++)
        c + Offset(math.cos(-math.pi / 2 + i * math.pi / 3), math.sin(-math.pi / 2 + i * math.pi / 3)) * r,
    ];
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final prev = pts[(i + 5) % 6], cur = pts[i], next = pts[(i + 1) % 6];
      final a = cur + (prev - cur) / (prev - cur).distance * round;
      final b = cur + (next - cur) / (next - cur).distance * round;
      i == 0 ? path.moveTo(a.dx, a.dy) : path.lineTo(a.dx, a.dy);
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return path..close();
  }

  void _stroke(Canvas canvas, Path p, double w, Color color) => canvas.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..color = color,
  );

  /// Gold badges: a 12-point rosette behind the hexagon.
  void _rosette(Canvas canvas, Offset c) {
    final p = Path();
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + i * math.pi / 12;
      final r = i.isEven ? 49.0 : 45.0;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    canvas.drawPath(
      p,
      Paint()
        ..color = _gold[1].withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gold[0], _gold[2]],
        ).createShader(Rect.fromCircle(center: c, radius: 49)),
    );
  }

  /// Rank chevrons: 1, 2 or 3 stacked "V"s.
  void _chevrons(Canvas canvas, Offset c, {double scale = 1}) {
    final n = tier.index + 1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = earned ? (style == MedalStyle.glass ? Colors.white : _metal[0]) : _metal[2];
    for (var i = 0; i < n; i++) {
      final y = c.dy + (i - (n - 1) / 2) * 4.6 * scale;
      final p = Path()
        ..moveTo(c.dx - 6.5 * scale, y - 2.4 * scale)
        ..lineTo(c.dx, y + 2.4 * scale)
        ..lineTo(c.dx + 6.5 * scale, y - 2.4 * scale);
      canvas.drawPath(p, paint);
    }
  }

  void _gloss(Canvas canvas, Rect r) {
    if (!earned) return;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)],
          stops: const [0, 0.5],
        ).createShader(r),
    );
  }

  void _glint(Canvas canvas, Path shape) {
    canvas.save();
    canvas.clipPath(shape);
    final x = -30 + 160 * shine;
    final p = Path()
      ..moveTo(x, 0)
      ..lineTo(x + 12, 0)
      ..lineTo(x - 18, 100)
      ..lineTo(x - 30, 100)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.restore();
  }

  // ----------------------------------------------------------- emblems

  void _emblem(Canvas canvas, Offset c, double scale) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    final color = earned ? Colors.white : const Color(0xFFB4BAC6);
    switch (season) {
      case Season.winter:
        _snowflake(canvas, color);
      case Season.spring:
        _blossom(canvas, color);
      case Season.summer:
        _sun(canvas, color);
      case Season.monsoon:
        _storm(canvas, color);
    }
    canvas.restore();
  }

  Paint _line(Color color, [double w = 2.6]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _snowflake(Canvas canvas, Color color) {
    final p = _line(color);
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      canvas.drawLine(const Offset(0, -3), const Offset(0, -21), p);
      for (final (y, len) in [(-16.0, 6.5), (-10.0, 4.5)]) {
        canvas.drawLine(Offset(0, y), Offset(-len * 0.85, y - len * 0.6), p);
        canvas.drawLine(Offset(0, y), Offset(len * 0.85, y - len * 0.6), p);
      }
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 2.6, Paint()..color = color);
  }

  void _blossom(Canvas canvas, Color color) {
    final line = _line(color);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 5);
      // A cherry petal with a notch at its tip.
      final petal = Path()
        ..moveTo(0, -4)
        ..cubicTo(-10, -10, -9, -21, -3, -23)
        ..lineTo(0, -20)
        ..lineTo(3, -23)
        ..cubicTo(9, -21, 10, -10, 0, -4);
      canvas.drawPath(petal, line);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 3, Paint()..color = color);
  }

  void _sun(Canvas canvas, Color color) {
    final p = _line(color);
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawLine(const Offset(0, -15), const Offset(0, -22), p);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 10.5, Paint()..color = color);
    canvas.drawCircle(Offset.zero, 13.5, _line(color, 1.6));
  }

  void _storm(Canvas canvas, Color color) {
    final cloud = Path()
      ..moveTo(-15, 6)
      ..cubicTo(-23, 6, -23, -6, -14, -7)
      ..cubicTo(-14, -18, 3, -20, 8, -10)
      ..cubicTo(17, -13, 24, -5, 18, 3)
      ..cubicTo(21, 6, 18, 8, 14, 8)
      ..lineTo(-12, 8)
      ..cubicTo(-14, 8, -16, 7, -15, 6)
      ..close();
    canvas.drawPath(cloud, _line(color));
    final bolt = Path()
      ..moveTo(3, 6)
      ..lineTo(-5, 18)
      ..lineTo(0, 18)
      ..lineTo(-3, 28)
      ..lineTo(8, 14)
      ..lineTo(2, 14)
      ..lineTo(6, 6)
      ..close();
    canvas.drawPath(bolt, Paint()..color = earned ? const Color(0xFFFFD43B) : color);
  }

  @override
  bool shouldRepaint(MedalPainter old) =>
      old.season != season || old.tier != tier || old.earned != earned || old.shine != shine || old.style != style;
}
