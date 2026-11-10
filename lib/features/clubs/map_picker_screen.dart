import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/gradient_button.dart';
import 'domain/club_challenge.dart';
import 'widgets/route_map.dart';

/// The planned route: the points the admin tapped, start first, finish last.
typedef PlannedRoute = List<(double, double)>;

/// Length of a planned route in metres.
double routeLength(PlannedRoute r) {
  var m = 0.0;
  for (var i = 1; i < r.length; i++) {
    m += distanceBetween(r[i - 1], r[i]);
  }
  return m;
}

/// The admin draws the challenge route by tapping along the roads: the
/// first tap is the start, the last is the finish. The distance is worked
/// out from the route.
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key, required this.around, this.initial = const []});

  /// Where to centre the map at first (the admin's location).
  final (double, double) around;
  final PlannedRoute initial;

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  late final PlannedRoute _points = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final length = routeLength(_points);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Draw the route')),
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              tooltip: tr('Undo last point'),
              icon: const Icon(Icons.undo_rounded),
              onPressed: () => setState(_points.removeLast),
            ),
          if (_points.isNotEmpty) TextButton(onPressed: () => setState(_points.clear), child: Text(tr('Clear'))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RouteMap(plan: _points, around: widget.around, onTap: (p) => setState(() => _points.add(p))),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _points.isEmpty
                        ? 'Tap where the challenge starts.'
                        : _points.length == 1
                        ? 'Now tap along the roads to the finish. Tap at each turn.'
                        : 'Route: ${formatKm(length.round())}. Keep tapping to extend it, or tap Done.',
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: tr('Done'),
                    icon: Icons.check_rounded,
                    onPressed: _points.isEmpty ? null : () => Navigator.of(context).pop<PlannedRoute>([..._points]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
