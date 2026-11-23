import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

typedef LatLngPair = (double, double);

/// The route drawn as a simple line, north up: green start, red finish.
/// FittArc shows no maps; GPS measures the distance.
class RouteSketch extends StatelessWidget {
  const RouteSketch({super.key, required this.route, this.plan = const [], this.start, this.finish, this.color});

  final List<LatLngPair> route;
  final List<LatLngPair> plan;
  final LatLngPair? start;
  final LatLngPair? finish;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SketchPainter(route, plan, start, finish, color ?? AppColors.primary, AppColors.accent),
    size: Size.infinite,
  );
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.route, this.plan, this.start, this.finish, this.color, this.planColor);

  final List<LatLngPair> route, plan;
  final LatLngPair? start, finish;
  final Color color, planColor;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...plan, ...route, ?start, ?finish];
    if (all.isEmpty) return;
    final k = math.cos(all.first.$1 * math.pi / 180);
    Offset raw(LatLngPair p) => Offset(p.$2 * k, -p.$1);
    final pts = [for (final p in all) raw(p)];
    var minX = pts.first.dx, maxX = minX, minY = pts.first.dy, maxY = minY;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const pad = 8.0;
    final w = math.max(maxX - minX, 1e-9), h = math.max(maxY - minY, 1e-9);
    final scale = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h);
    final dx = (size.width - w * scale) / 2, dy = (size.height - h * scale) / 2;
    Offset map(LatLngPair p) {
      final r = raw(p);
      return Offset(dx + (r.dx - minX) * scale, dy + (r.dy - minY) * scale);
    }

    void line(List<LatLngPair> l, Color c, double width) {
      if (l.length < 2) return;
      final path = Path()..moveTo(map(l.first).dx, map(l.first).dy);
      for (final p in l.skip(1)) {
        final m = map(p);
        path.lineTo(m.dx, m.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    line(plan, planColor.withValues(alpha: 0.45), 7);
    line(route, color, 3.2);
    final s = start ?? (plan.isNotEmpty ? plan.first : (route.isEmpty ? null : route.first));
    final f = finish ?? (plan.length > 1 ? plan.last : (route.length > 1 ? route.last : null));
    if (s != null) canvas.drawCircle(map(s), 5, Paint()..color = const Color(0xFF2E8B57));
    if (f != null) canvas.drawCircle(map(f), 5, Paint()..color = const Color(0xFFC0392B));
  }

  @override
  bool shouldRepaint(_SketchPainter old) => old.route != route || old.plan != plan || old.color != color;
}
