import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Full-screen "you're in" moment after a successful sign-in: a circle draws
/// itself, a check strokes in, the greeting rises, then the layer fades away.
///
/// It lives in the root overlay rather than as a route, so it keeps playing
/// while the router moves on to the next screen underneath.
void showAuthSuccess(BuildContext context, {String? name}) {
  HapticFeedback.mediumImpact();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SuccessView(name: name, onDone: entry.remove),
  );
  overlay.insert(entry);
}

class _SuccessView extends StatefulWidget {
  const _SuccessView({required this.onDone, this.name});

  final String? name;
  final VoidCallback onDone;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> with SingleTickerProviderStateMixin {
  // 0–0.15 fade in · 0.15–0.8 draw + greet · 0.85–1 fade out.
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.name?.split(' ').first;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final opacity = v < 0.15 ? v / 0.15 : (v > 0.85 ? (1 - v) / 0.15 : 1.0);
        final t = ((v - 0.1) / 0.65).clamp(0.0, 1.0);
        final words = Curves.easeOutCubic.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
        final text = Theme.of(context).textTheme;
        return IgnorePointer(
          ignoring: v > 0.85,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Material(
              color: AppColors.background,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: 92, child: CustomPaint(painter: _CheckPainter(t))),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: words,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - words)),
                        child: Column(
                          children: [
                            Text(first == null ? "You're in" : 'Welcome, $first', style: text.headlineSmall),
                            const SizedBox(height: 4),
                            Text("Let's set up your mornings.", style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final fill = Curves.easeOutBack.transform(((t - 0.35) / 0.3).clamp(0.0, 1.0));
    final ring = Curves.easeInOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
    final check = Curves.easeOutCubic.transform(((t - 0.45) / 0.35).clamp(0.0, 1.0));

    // Soft filled disc grows in behind the ring.
    canvas.drawCircle(c, r * 0.92 * fill, Paint()..color = AppColors.primary);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 2),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (check > 0) {
      final path = Path()
        ..moveTo(c.dx - r * 0.32, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.08, c.dy + r * 0.26)
        ..lineTo(c.dx + r * 0.36, c.dy - r * 0.2);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * check),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
