import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/health.dart';

/// A small coloured pill naming how a reading sorts, e.g. "Normal".
class RatingChip extends StatelessWidget {
  const RatingChip({super.key, required this.rating});

  final Rating rating;

  @override
  Widget build(BuildContext context) {
    final c = rating.level.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        rating.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The last readings as a line, oldest to newest. Blood pressure draws two
/// lines (top and bottom number).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.kind, required this.readings, this.height = 46});

  final ReadingKind kind;

  /// Newest first, as the providers return them.
  final List<HealthReading> readings;
  final double height;

  @override
  Widget build(BuildContext context) {
    final recent = readings.take(14).toList().reversed.toList();
    if (recent.length < 2) {
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Add another reading to see a trend', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(kind, recent, AppColors.primary, AppColors.textMuted)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.kind, this.readings, this.color, this.faint);

  final ReadingKind kind;
  final List<HealthReading> readings;
  final Color color;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = <List<double>>[
      if (kind == ReadingKind.bloodPressure) ...[
        [for (final r in readings) r.systolic!.toDouble()],
        [for (final r in readings) r.diastolic!.toDouble()],
      ] else
        [for (final r in readings) r.value!.toDouble()],
    ];
    final all = lines.expand((l) => l);
    var lo = all.reduce((a, b) => a < b ? a : b), hi = all.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 10) {
      final mid = (hi + lo) / 2;
      lo = mid - 5;
      hi = mid + 5;
    }
    const pad = 4.0;
    Offset at(int i, double v) => Offset(
      pad + (size.width - pad * 2) * (i / (readings.length - 1)),
      pad + (size.height - pad * 2) * (1 - (v - lo) / (hi - lo)),
    );
    for (var n = 0; n < lines.length; n++) {
      final c = n == 0 ? color : faint;
      final path = Path();
      for (var i = 0; i < lines[n].length; i++) {
        final p = at(i, lines[n][i]);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(at(lines[n].length - 1, lines[n].last), 3.4, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.readings != readings || old.color != color;
}

/// The pulse wave while measuring: a line that rises and falls with each beat.
class WavePainter extends CustomPainter {
  WavePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce((a, b) => a < b ? a : b), hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(size.width * i / (values.length - 1), size.height * (1 - (values[i] - lo) / (hi - lo)));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(WavePainter old) => true;
}
