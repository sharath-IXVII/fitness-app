import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/widgets/gradient_button.dart';
import 'domain/club_challenge.dart';

typedef StartFinish = ({(double, double) start, (double, double)? finish});

/// The admin taps the map to set the start, then (optionally) the finish.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, required this.around, this.start, this.finish});

  /// Where to centre the map at first (the admin's location).
  final (double, double) around;
  final (double, double)? start;
  final (double, double)? finish;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late (double, double)? _start = widget.start;
  late (double, double)? _finish = widget.finish;

  void _tap(LatLng p) => setState(() {
    if (_start == null) {
      _start = (p.latitude, p.longitude);
    } else {
      _finish = (p.latitude, p.longitude);
    }
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = _start != null && _finish != null ? distanceBetween(_start!, _finish!) : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start and finish'),
        actions: [
          if (_start != null)
            TextButton(onPressed: () => setState(() => _start = _finish = null), child: const Text('Reset')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(widget.around.$1, widget.around.$2), zoom: 15),
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              onTap: _tap,
              markers: {
                if (_start case final s?)
                  Marker(
                    markerId: const MarkerId('start'),
                    position: LatLng(s.$1, s.$2),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    infoWindow: const InfoWindow(title: 'Start'),
                  ),
                if (_finish case final f?)
                  Marker(
                    markerId: const MarkerId('finish'),
                    position: LatLng(f.$1, f.$2),
                    infoWindow: const InfoWindow(title: 'Finish'),
                  ),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _start == null
                        ? 'Tap the map where the challenge starts.'
                        : _finish == null
                        ? 'Now tap where it finishes, or tap Done to finish anywhere.'
                        : 'Start to finish: ${formatKm(line!.round())} in a straight line. '
                              'Set the distance to the route people will take.',
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    onPressed: _start == null
                        ? null
                        : () => Navigator.of(context).pop<StartFinish>((start: _start!, finish: _finish)),
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
