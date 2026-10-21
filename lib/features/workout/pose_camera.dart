import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'domain/rep_counter.dart';

/// Front camera + ML Kit pose detection. Emits landmarks for every frame
/// the detector processes (frames that arrive while it's busy are dropped).
class PoseCamera {
  PoseCamera({required this.onPose});

  final void Function(Landmarks? landmarks, Size imageSize, InputImageRotation rotation) onPose;

  CameraController? controller;
  CameraDescription? _camera;
  final _detector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  bool _busy = false;
  bool _disposed = false;

  bool get isFront => _camera?.lensDirection == CameraLensDirection.front;

  Future<void> start() async {
    final cameras = await availableCameras();
    _camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    final c = CameraController(
      _camera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await c.initialize();
    if (_disposed) {
      await c.dispose();
      return;
    }
    controller = c;
    await c.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _disposed) return;
    final input = _toInputImage(image);
    if (input == null) return;
    _busy = true;
    try {
      final poses = await _detector.processImage(input);
      if (_disposed) return;
      onPose(poses.isEmpty ? null : poses.first.landmarks, input.metadata!.size, input.metadata!.rotation);
    } catch (e) {
      debugPrint('pose detection failed: $e');
    } finally {
      _busy = false;
    }
  }

  static const _deviceOrientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // Adapted from the google_mlkit_commons camera example.
  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera, c = controller;
    if (camera == null || c == null) return null;

    final sensor = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _deviceOrientations[c.value.deviceOrientation];
      if (comp == null) return null;
      comp = camera.lensDirection == CameraLensDirection.front ? (sensor + comp) % 360 : (sensor - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    final c = controller;
    controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.dispose();
    }
    await _detector.close();
  }
}
