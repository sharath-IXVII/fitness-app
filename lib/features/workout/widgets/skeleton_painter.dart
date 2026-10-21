import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/rep_counter.dart';

/// Draws the detected body over the camera preview.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.landmarks,
    required this.imageSize,
    required this.rotation,
    required this.mirrored,
    required this.good,
  });

  final Landmarks? landmarks;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool mirrored;

  /// Tints the skeleton green when the body is tracked and form is fine.
  final bool good;

  static const _bones = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  Offset _map(PoseLandmark p, Size canvas) {
    final sideways = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
    final w = sideways ? imageSize.height : imageSize.width;
    final h = sideways ? imageSize.width : imageSize.height;
    var x = p.x * canvas.width / w;
    final y = p.y * canvas.height / h;
    if (mirrored && Platform.isAndroid) x = canvas.width - x;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lm = landmarks;
    if (lm == null) return;
    final color = good ? AppColors.accent : Colors.white;

    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final bone = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (final (a, b) in _bones) {
      final pa = lm[a], pb = lm[b];
      if (pa == null || pb == null || pa.likelihood < 0.5 || pb.likelihood < 0.5) continue;
      final oa = _map(pa, size), ob = _map(pb, size);
      canvas.drawLine(oa, ob, glow);
      canvas.drawLine(oa, ob, bone);
    }

    final dot = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final (a, b) in _bones) {
      for (final t in [a, b]) {
        final p = lm[t];
        if (p == null || p.likelihood < 0.5) continue;
        final o = _map(p, size);
        canvas.drawCircle(o, 6, dot);
        canvas.drawCircle(o, 6, ring);
      }
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => old.landmarks != landmarks || old.good != good;
}
