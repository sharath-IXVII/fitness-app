import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/daily_log.dart';

/// LeetCode-style streak calendar: one block per month (weeks as columns,
/// Mon–Sun as rows), each on its own panel so months read as separate units.
/// The current month is highlighted. Cell size is derived from the width so
/// it always fits without scrolling.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key, required this.scores, this.months = 4});

  final Map<DateTime, DayScore> scores;
  final int months;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  DateTime? _selected;

  static const _gap = 3.0;
  static const _blockPad = 5.0;
  static const _blockGap = 6.0;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// Weeks (columns) a month spans in a Monday-first grid.
  static int columnsFor(DateTime month) {
    final offset = DateTime(month.year, month.month).weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return ((offset + days) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final months = [for (var i = widget.months - 1; i >= 0; i--) DateTime(today.year, today.month - i)];
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);

    return LayoutBuilder(
      builder: (context, box) {
        final cols = months.fold(0, (n, m) => n + columnsFor(m));
        final fixed =
            months.length * 2 * (_blockPad + 1) + (months.length - 1) * _blockGap + (cols - months.length) * _gap;
        final cell = math.min(16.0, (box.maxWidth - fixed) / cols).floorToDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, m) in months.indexed) ...[
                  if (i > 0) const SizedBox(width: _blockGap),
                  _month(m, today, cell, i, labelStyle),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: Text(
                      _selectedLabel(),
                      key: ValueKey(_selected),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Text('Less', style: labelStyle),
                const SizedBox(width: 6),
                for (final c in AppColors.heat)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
                  ),
                const SizedBox(width: 6),
                Text('More', style: labelStyle),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _month(DateTime month, DateTime today, double cell, int index, TextStyle? labelStyle) {
    final current = month.year == today.year && month.month == today.month;
    final offset = month.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final cols = columnsFor(month);
    final active = widget.scores.entries
        .where((e) => e.key.year == month.year && e.key.month == month.month && e.value.keepsStreak)
        .length;
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(index * 0.15, math.min(1, index * 0.15 + 0.55), curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: anim,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(_blockPad),
            decoration: BoxDecoration(
              color: current ? AppColors.primarySoft : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: current ? AppColors.primary.withValues(alpha: 0.5) : AppColors.stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding: EdgeInsets.only(right: c == cols - 1 ? 0 : _gap),
                    child: Column(
                      children: [
                        for (var r = 0; r < 7; r++)
                          Padding(
                            padding: EdgeInsets.only(bottom: r == 6 ? 0 : _gap),
                            child: _cell(c * 7 + r - offset + 1, month, days, today, cell),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.MMM().format(month),
            style: labelStyle?.copyWith(
              color: current ? AppColors.textPrimary : AppColors.textTertiary,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text('$active days', style: labelStyle?.copyWith(fontSize: 10, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _cell(int dayNumber, DateTime month, int days, DateTime today, double size) {
    if (dayNumber < 1 || dayNumber > days) return SizedBox.square(dimension: size);
    final day = DateTime(month.year, month.month, dayNumber);
    final future = day.isAfter(today);
    final level = widget.scores[day]?.level ?? 0;
    final isToday = day == today;
    final selected = day == _selected;
    return GestureDetector(
      onTap: future
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _selected = selected ? null : day);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: future ? AppColors.surface : AppColors.heat[level],
          borderRadius: BorderRadius.circular(size * 0.25),
          border: selected || isToday
              ? Border.all(color: selected ? AppColors.textPrimary : AppColors.primary, width: 1.4)
              : (future ? Border.all(color: AppColors.stroke, width: 0.6) : null),
        ),
      ),
    );
  }

  String _selectedLabel() {
    final s = _selected;
    if (s == null) return 'Tap a day for details';
    final count = widget.scores[s]?.count ?? 0;
    return '${DateFormat('EEE, d MMM').format(s)} · $count of ${DayScore.total} goals';
  }
}
