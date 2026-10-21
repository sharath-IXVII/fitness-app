import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// Seven-day bar chart with a dashed goal line. Bars grow in on first show.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.days, required this.goal, this.format, this.height = 120});

  final List<(DateTime, num)> days;
  final num goal;
  final String Function(num)? format;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxV = math.max(goal.toDouble(), days.fold(0.0, (m, d) => math.max(m, d.$2.toDouble()))) * 1.1;
    final today = DateUtils.dateOnly(DateTime.now());
    return SizedBox(
      height: height + 34,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: height * (1 - goal / maxV),
            child: CustomPaint(size: const Size(double.infinity, 1), painter: _Dashes()),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, (d, v)) in days.indexed)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: maxV == 0 ? 0 : v / maxV),
                        duration: Duration(milliseconds: 500 + i * 40),
                        curve: Curves.easeOutCubic,
                        builder: (_, f, _) => Container(
                          width: 18,
                          height: math.max(4, height * f),
                          decoration: BoxDecoration(
                            color: v >= goal ? AppColors.primary : AppColors.heat[2],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat.E().format(d).substring(0, 1),
                        style: text.labelSmall?.copyWith(
                          color: d == today ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: d == today ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Text(
                        format?.call(v) ?? '',
                        style: text.labelSmall?.copyWith(fontSize: 9, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => false;
}
