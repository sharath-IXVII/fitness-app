import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/daily_log.dart';

/// LeetCode / GitHub-style contribution grid. Columns are weeks (Mon–Sun),
/// the newest week is on the right and is scrolled into view by default.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key, required this.scores, this.weeks = 26, this.cell = 13});

  final Map<DateTime, DayScore> scores;
  final int weeks;
  final double cell;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  DateTime? _selected;

  static const _gap = 3.5;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(Duration(days: 7 * (widget.weeks - 1)));
    final step = widget.cell + _gap;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10);

    final columns = <Widget>[];
    for (var w = 0; w < widget.weeks; w++) {
      final weekStart = start.add(Duration(days: 7 * w));
      final showMonth = weekStart.day <= 7;
      columns.add(
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 16,
                width: widget.cell,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: 40,
                  child: showMonth ? Text(DateFormat.MMM().format(weekStart), style: labelStyle) : null,
                ),
              ),
              for (var d = 0; d < 7; d++) _cell(weekStart.add(Duration(days: d)), today, w),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 6),
              child: Column(
                children: [
                  for (final l in ['M', '', 'W', '', 'F', '', 'S'])
                    SizedBox(
                      height: step,
                      child: Text(l, style: labelStyle),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                physics: const BouncingScrollPhysics(),
                child: Row(children: columns),
              ),
            ),
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
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
  }

  String _selectedLabel() {
    final s = _selected;
    if (s == null) return 'Tap a day for details';
    final count = widget.scores[s]?.count ?? 0;
    return '${DateFormat('EEE, d MMM').format(s)} · $count/${DayScore.total} tasks';
  }

  Widget _cell(DateTime day, DateTime today, int week) {
    final future = day.isAfter(today);
    final level = widget.scores[day]?.level ?? 0;
    final isToday = day == today;
    final selected = day == _selected;

    // Stagger the intro so the grid "fills in" from left to right.
    final begin = (week / widget.weeks) * 0.6;
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, begin + 0.4, curve: Curves.easeOut),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: FadeTransition(
        opacity: anim,
        child: GestureDetector(
          onTap: future
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = selected ? null : day);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: widget.cell,
            height: widget.cell,
            decoration: BoxDecoration(
              color: future ? Colors.transparent : AppColors.heat[level],
              borderRadius: BorderRadius.circular(3.5),
              border: Border.all(
                color: selected
                    ? Colors.white
                    : isToday
                    ? AppColors.lime.withValues(alpha: 0.8)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                if (level == 4)
                  BoxShadow(color: AppColors.lime.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: -1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
