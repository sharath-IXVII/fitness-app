import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/app_colors.dart';

/// Free maps: OpenFreeMap (OpenStreetMap data) through MapLibre. No key, no
/// billing. Only on phones; elsewhere (and in tests) routes are drawn
/// without a map.
bool get hasMaps => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

const mapStyle = 'https://tiles.openfreemap.org/styles/liberty';

typedef LatLngPair = (double, double);

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A map with the planned route (wide, soft), the route actually covered
/// (bold), and start (green) and finish (red) dots. [follow] keeps the
/// camera on the runner. [onTap] lets the admin draw a route.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    this.route = const [],
    this.plan = const [],
    this.start,
    this.finish,
    this.follow = false,
    this.onTap,
    this.around,
  });

  /// Where the person actually went.
  final List<LatLngPair> route;

  /// The route the admin drew, for members to follow.
  final List<LatLngPair> plan;
  final LatLngPair? start;
  final LatLngPair? finish;
  final bool follow;
  final void Function(LatLngPair point)? onTap;

  /// Where to look when there's nothing to show yet.
  final LatLngPair? around;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MapLibreMapController? _map;
  bool _ready = false;
  bool _fitted = false;

  LatLng _ll(LatLngPair p) => LatLng(p.$1, p.$2);

  List<LatLngPair> get _all => [...widget.plan, ...widget.route, ?widget.start, ?widget.finish];

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    _draw();
    if (widget.follow && widget.route.isNotEmpty && widget.route.length != old.route.length) {
      _map?.animateCamera(CameraUpdate.newLatLng(_ll(widget.route.last)));
    }
  }

  Future<void> _draw() async {
    final m = _map;
    if (m == null || !_ready) return;
    try {
      await m.clearLines();
      await m.clearCircles();
      if (widget.plan.length > 1) {
        await m.addLine(
          LineOptions(
            geometry: [for (final p in widget.plan) _ll(p)],
            lineColor: _hex(AppColors.accent),
            lineWidth: 9,
            lineOpacity: 0.55,
            lineJoin: 'round',
          ),
        );
      }
      if (widget.route.length > 1) {
        await m.addLine(
          LineOptions(
            geometry: [for (final p in widget.route) _ll(p)],
            lineColor: _hex(AppColors.primary),
            lineWidth: 5,
            lineJoin: 'round',
          ),
        );
      }
      final s = widget.start ?? (widget.plan.isNotEmpty ? widget.plan.first : null);
      final f = widget.finish ?? (widget.plan.length > 1 ? widget.plan.last : null);
      for (final (p, c) in [(s, '#2E8B57'), (f, '#C0392B')]) {
        if (p == null) continue;
        await m.addCircle(
          CircleOptions(
            geometry: _ll(p),
            circleRadius: 8,
            circleColor: c,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
      }
      if (!_fitted) _fit();
    } catch (e) {
      debugPrint('map draw: $e');
    }
  }

  void _fit() {
    final pts = _all;
    final m = _map;
    if (m == null || pts.isEmpty) return;
    _fitted = true;
    if (pts.length == 1 || widget.follow) {
      m.moveCamera(CameraUpdate.newLatLngZoom(_ll(widget.route.isNotEmpty ? widget.route.last : pts.first), 16));
      return;
    }
    var s = pts.first.$1, n = s, w = pts.first.$2, e = w;
    for (final (lat, lng) in pts) {
      s = math.min(s, lat);
      n = math.max(n, lat);
      w = math.min(w, lng);
      e = math.max(e, lng);
    }
    m.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
        left: 40,
        top: 40,
        right: 40,
        bottom: 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasMaps) {
      return RouteSketch(route: widget.route, plan: widget.plan, start: widget.start, finish: widget.finish);
    }
    final first = _all.isNotEmpty ? _all.first : (widget.around ?? const (12.97, 77.59));
    return MapLibreMap(
      styleString: mapStyle,
      initialCameraPosition: CameraPosition(target: _ll(first), zoom: 15),
      onMapCreated: (c) => _map = c,
      onStyleLoadedCallback: () {
        _ready = true;
        _draw();
      },
      onMapClick: widget.onTap == null ? null : (_, ll) => widget.onTap!((ll.latitude, ll.longitude)),
      myLocationEnabled: widget.follow || widget.onTap != null,
      compassEnabled: false,
      trackCameraPosition: false,
    );
  }
}

/// The route drawn as a line, north up, when there's no map (or for the
/// saved report picture, which can't contain a live map).
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
