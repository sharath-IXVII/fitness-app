import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/daily_log.dart';

/// Contribution grid (weeks as columns, Mon–Sun as rows) that always fits
/// the available width — cell size is derived from it, so there's no
/// sideways scrolling.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key, required this.scores, this.weeks = 17});

  final Map<DateTime, DayScore> scores;
  final int weeks;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  DateTime? _selected;

  static const _gap = 4.0;
  static const _labelWidth = 18.0;

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
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: AppColors.textMuted);

    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - _labelWidth - _gap * (widget.weeks - 1)) / widget.weeks;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month labels, positioned over the first week of each month.
            SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var w = 0; w < widget.weeks; w++)
                    if (start.add(Duration(days: 7 * w)).day <= 7)
                      Positioned(
                        left: _labelWidth + w * (cell + _gap),
                        child: Text(DateFormat.MMM().format(start.add(Duration(days: 7 * w))), style: labelStyle),
                      ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Column(
                    children: [
                      for (final l in ['M', '', 'W', '', 'F', '', 'S'])
                        SizedBox(
                          height: cell + _gap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(l, style: labelStyle),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var w = 0; w < widget.weeks; w++)
                  Padding(
                    padding: EdgeInsets.only(right: w == widget.weeks - 1 ? 0 : _gap),
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++) _cell(start.add(Duration(days: 7 * w + d)), today, w, cell),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
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
                    width: 11,
                    height: 11,
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

  String _selectedLabel() {
    final s = _selected;
    if (s == null) return 'Tap a day for details';
    final count = widget.scores[s]?.count ?? 0;
    return '${DateFormat('EEE, d MMM').format(s)} · $count of ${DayScore.total} goals';
  }

  Widget _cell(DateTime day, DateTime today, int week, double size) {
    final future = day.isAfter(today);
    final level = widget.scores[day]?.level ?? 0;
    final isToday = day == today;
    final selected = day == _selected;

    // Stagger the intro so the grid fills in from left to right.
    final begin = (week / widget.weeks) * 0.6;
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, begin + 0.4, curve: Curves.easeOutBack),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: ScaleTransition(
        scale: anim,
        child: GestureDetector(
          onTap: future
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = selected ? null : day);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: future ? AppColors.heat[0].withValues(alpha: 0.35) : AppColors.heat[level],
              borderRadius: BorderRadius.circular(size * 0.28),
              border: selected || isToday
                  ? Border.all(color: selected ? AppColors.textPrimary : AppColors.primary, width: 1.6)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
