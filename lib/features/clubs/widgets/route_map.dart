import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// True when the build has a Google Maps key (set by CI from the
/// MAPS_API_KEY secret). Without it routes are drawn without a map.
const hasMaps = bool.fromEnvironment('HAS_MAPS');

/// A route on Google Maps, with start (green) and finish (red) markers.
/// [follow] keeps the camera on the newest point (while running).
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.route, this.start, this.finish, this.follow = false});

  final List<(double, double)> route;
  final (double, double)? start;
  final (double, double)? finish;
  final bool follow;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  GoogleMapController? _map;

  LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

  List<(double, double)> get _all => [...widget.route, ?widget.start, ?widget.finish];

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (widget.follow && widget.route.isNotEmpty && widget.route.length != old.route.length) {
      _map?.animateCamera(CameraUpdate.newLatLng(_ll(widget.route.last)));
    }
  }

  void _fit() {
    final pts = _all;
    if (_map == null || pts.isEmpty) return;
    if (pts.length == 1 || widget.follow) {
      _map!.moveCamera(
        CameraUpdate.newLatLngZoom(_ll(widget.follow && widget.route.isNotEmpty ? widget.route.last : pts.first), 16),
      );
      return;
    }
    var s = pts.first.$1, n = s, w = pts.first.$2, e = w;
    for (final (lat, lng) in pts) {
      s = math.min(s, lat);
      n = math.max(n, lat);
      w = math.min(w, lng);
      e = math.max(e, lng);
    }
    _map!.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)), 40));
  }

  @override
  Widget build(BuildContext context) {
    if (!hasMaps) return RouteSketch(route: widget.route, start: widget.start, finish: widget.finish);
    final first = _all.isEmpty ? const (12.97, 77.59) : _all.first;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _ll(first), zoom: 15),
      onMapCreated: (c) {
        _map = c;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
      },
      myLocationEnabled: widget.follow,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      polylines: {
        if (widget.route.length > 1)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [for (final p in widget.route) _ll(p)],
            color: AppColors.primary,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      markers: {
        if (widget.start ?? (widget.route.isEmpty ? null : widget.route.first) case final p?)
          Marker(
            markerId: const MarkerId('start'),
            position: _ll(p),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Start'),
          ),
        if (widget.finish case final p?)
          Marker(
            markerId: const MarkerId('finish'),
            position: _ll(p),
            infoWindow: const InfoWindow(title: 'Finish'),
          ),
      },
    );
  }
}

/// The route drawn as a line, north up, when there's no map (or for the
/// saved report picture, which can't contain a live map).
class RouteSketch extends StatelessWidget {
  const RouteSketch({super.key, required this.route, this.start, this.finish, this.color});

  final List<(double, double)> route;
  final (double, double)? start;
  final (double, double)? finish;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SketchPainter(route, start, finish, color ?? AppColors.primary), size: Size.infinite);
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.route, this.start, this.finish, this.color);

  final List<(double, double)> route;
  final (double, double)? start, finish;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...route, ?start, ?finish];
    if (all.isEmpty) return;
    final k = math.cos(all.first.$1 * math.pi / 180);
    Offset raw((double, double) p) => Offset(p.$2 * k, -p.$1);
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
    Offset map((double, double) p) {
      final r = raw(p);
      return Offset(dx + (r.dx - minX) * scale, dy + (r.dy - minY) * scale);
    }

    if (route.length > 1) {
      final path = Path()..moveTo(map(route.first).dx, map(route.first).dy);
      for (final p in route.skip(1)) {
        final m = map(p);
        path.lineTo(m.dx, m.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    final s = start ?? (route.isEmpty ? null : route.first);
    final f = finish ?? (route.length > 1 ? route.last : null);
    if (s != null) canvas.drawCircle(map(s), 5, Paint()..color = const Color(0xFF2E8B57));
    if (f != null) canvas.drawCircle(map(f), 5, Paint()..color = const Color(0xFFC0392B));
  }

  @override
  bool shouldRepaint(_SketchPainter old) => old.route != route || old.color != color;
}
