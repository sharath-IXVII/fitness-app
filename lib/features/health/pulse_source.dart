import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/pulse_signal.dart';

/// Where heart-rate frames come from. The real one is the phone's back
/// camera with the flash on; tests give it a pretend signal.
abstract class PulseSource {
  /// Starts the camera. Errors (no permission, no flash) arrive on the stream.
  Stream<PulseSample> start();

  Future<void> stop();
}

final pulseSourceProvider = Provider<PulseSource>((ref) => CameraPulseSource());

/// A fingertip pressed on the back camera and flash. With the flash on, the
/// finger glows red, and every heartbeat changes how much light passes
/// through, which shows up as a tiny rise and fall in the picture's
/// brightness.
class CameraPulseSource implements PulseSource {
  CameraController? _controller;
  StreamController<PulseSample>? _out;
  bool _stopped = false;

  @override
  Stream<PulseSample> start() {
    final out = _out = StreamController<PulseSample>();
    _open(out);
    return out.stream;
  }

  Future<void> _open(StreamController<PulseSample> out) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera found on this phone.');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final c = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );
      await c.initialize();
      if (_stopped) {
        await c.dispose();
        return;
      }
      _controller = c;
      try {
        await c.setFlashMode(FlashMode.torch);
      } catch (_) {
        throw StateError('This phone\'s camera has no flash to light your fingertip.');
      }
      await c.startImageStream((image) {
        final s = _sample(image);
        if (s != null && !out.isClosed) out.add(s);
      });
    } on CameraException catch (e) {
      if (!out.isClosed) {
        out.addError(
          e.code.toLowerCase().contains('denied')
              ? 'Camera permission is off. Allow the camera for FittArc in Settings and try again.'
              : 'The camera could not start (${e.code}).',
        );
      }
    } catch (e) {
      if (!out.isClosed) out.addError('$e'.replaceFirst('Bad state: ', ''));
    }
  }

  /// Average brightness of the middle of the picture, and whether it looks
  /// like a finger lit from behind (very red).
  PulseSample? _sample(CameraImage image) {
    try {
      final micros = DateTime.now().microsecondsSinceEpoch;
      final w = image.width, h = image.height;
      final x0 = w ~/ 4, x1 = w * 3 ~/ 4, y0 = h ~/ 4, y1 = h * 3 ~/ 4;
      if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
        final yPlane = image.planes[0], vPlane = image.planes[2];
        var sumY = 0, sumV = 0, n = 0;
        final vPixel = vPlane.bytesPerPixel ?? 1;
        for (var y = y0; y < y1; y += 4) {
          for (var x = x0; x < x1; x += 4) {
            sumY += yPlane.bytes[y * yPlane.bytesPerRow + x];
            sumV += vPlane.bytes[(y ~/ 2) * vPlane.bytesPerRow + (x ~/ 2) * vPixel];
            n++;
          }
        }
        if (n == 0) return null;
        final meanY = sumY / n, meanV = sumV / n;
        // A lit fingertip is strongly red (high Cr) and not black.
        return PulseSample(micros, meanY, fingerOn: meanV >= 160 && meanY >= 25);
      }
      final plane = image.planes[0];
      var sumR = 0, sumG = 0, n = 0;
      for (var y = y0; y < y1; y += 4) {
        for (var x = x0; x < x1; x += 4) {
          final i = y * plane.bytesPerRow + x * 4;
          sumG += plane.bytes[i + 1];
          sumR += plane.bytes[i + 2]; // BGRA
          n++;
        }
      }
      if (n == 0) return null;
      final meanR = sumR / n, meanG = sumG / n;
      return PulseSample(micros, meanR, fingerOn: meanR >= 150 && meanR > 1.8 * meanG);
    } catch (e) {
      debugPrint('pulse frame skipped: $e');
      return null;
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final c = _controller;
    _controller = null;
    try {
      if (c != null) {
        if (c.value.isStreamingImages) await c.stopImageStream();
        await c.setFlashMode(FlashMode.off);
        await c.dispose();
      }
    } catch (e) {
      debugPrint('pulse camera stop: $e');
    }
    await _out?.close();
  }
}
