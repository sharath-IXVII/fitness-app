import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/daily_log.dart';

/// LeetCode-style streak calendar for one month at a time. Swipe, use the
/// arrows, or tap the month name to jump to any earlier month.
class MonthHeatmap extends StatefulWidget {
  const MonthHeatmap({super.key, required this.scores, this.maxMonthsBack = 24});

  final Map<DateTime, DayScore> scores;

  /// How far back the user can browse when there's no older history.
  final int maxMonthsBack;

  @override
  State<MonthHeatmap> createState() => _MonthHeatmapState();
}

class _MonthHeatmapState extends State<MonthHeatmap> {
  late final DateTime _today = dayOnly(DateTime.now());
  late final List<DateTime> _months = _buildMonths();
  late final PageController _pages = PageController(initialPage: _months.length - 1);
  late int _index = _months.length - 1;
  DateTime? _selected;

  static const _gap = 5.0;

  /// From the earliest month with history (at most [maxMonthsBack] back,
  /// at least the last 6 months) up to this month, oldest first.
  List<DateTime> _buildMonths() {
    var back = 5;
    for (final d in widget.scores.keys) {
      final diff = (_today.year - d.year) * 12 + _today.month - d.month;
      back = math.max(back, diff);
    }
    back = math.min(back, widget.maxMonthsBack);
    return [for (var i = back; i >= 0; i--) DateTime(_today.year, _today.month - i)];
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= _months.length) return;
    HapticFeedback.selectionClick();
    _pages.animateToPage(index, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _pickMonth() async {
    final text = Theme.of(context).textTheme;
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Go to month', style: text.titleLarge),
              ),
              for (var i = _months.length - 1; i >= 0; i--)
                ListTile(
                  title: Text(DateFormat.yMMMM().format(_months[i]), style: text.titleSmall),
                  trailing: Text('${_activeDays(_months[i])} active days', style: text.bodySmall),
                  selected: i == _index,
                  selectedColor: AppColors.primary,
                  onTap: () => Navigator.pop(c, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _go(picked);
  }

  int _activeDays(DateTime month) => widget.scores.entries
      .where((e) => e.key.year == month.year && e.key.month == month.month && e.value.keepsStreak)
      .length;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final month = _months[_index];
    return LayoutBuilder(
      builder: (context, box) {
        final cell = ((box.maxWidth - 6 * _gap) / 7).floorToDouble();
        final rows = _rowsFor(month);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Arrow(
                  icon: Icons.chevron_left_rounded,
                  label: 'Previous month',
                  onTap: _index > 0 ? () => _go(_index - 1) : null,
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Choose month',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickMonth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat.yMMMM().format(month), style: text.titleMedium),
                            const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _Arrow(
                  icon: Icons.chevron_right_rounded,
                  label: 'Next month',
                  onTap: _index < _months.length - 1 ? () => _go(_index + 1) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (i, d) in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].indexed)
                  Container(
                    width: cell,
                    margin: EdgeInsets.only(right: i == 6 ? 0 : _gap),
                    alignment: Alignment.center,
                    child: Text(d, style: text.labelSmall?.copyWith(color: AppColors.textTertiary)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: rows * cell + (rows - 1) * _gap,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _months.length,
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _selected = null;
                  }),
                  itemBuilder: (_, i) => _grid(_months[i], cell),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _summary(month, text),
          ],
        );
      },
    );
  }

  static int _rowsFor(DateTime month) {
    final offset = DateTime(month.year, month.month).weekday - 1;
    return ((offset + DateUtils.getDaysInMonth(month.year, month.month)) / 7).ceil();
  }

  Widget _grid(DateTime month, double cell) {
    final offset = DateTime(month.year, month.month).weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = _rowsFor(month);
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : _gap),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Padding(
                    padding: EdgeInsets.only(right: c == 6 ? 0 : _gap),
                    child: _cell(r * 7 + c - offset + 1, month, days, cell),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int dayNumber, DateTime month, int days, double size) {
    if (dayNumber < 1 || dayNumber > days) return SizedBox.square(dimension: size);
    final day = DateTime(month.year, month.month, dayNumber);
    final future = day.isAfter(_today);
    final level = widget.scores[day]?.level ?? 0;
    final isToday = day == _today;
    final selected = day == _selected;
    final dark = level >= 3;
    return Semantics(
      label: '${DateFormat.MMMMd().format(day)}, ${widget.scores[day]?.count ?? 0} of ${DayScore.total} goals',
      child: GestureDetector(
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: future ? AppColors.surface : AppColors.heat[level],
            borderRadius: BorderRadius.circular(size * 0.24),
            border: selected || isToday
                ? Border.all(color: selected ? AppColors.textPrimary : AppColors.primary, width: 1.6)
                : (future ? Border.all(color: AppColors.stroke, width: 0.8) : null),
          ),
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: future
                  ? AppColors.textMuted
                  : dark
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(DateTime month, TextTheme text) {
    final s = _selected;
    if (s != null) {
      final count = widget.scores[s]?.count ?? 0;
      final done = widget.scores[s]?.completed ?? const <DailyTask>{};
      return Text(
        '${DateFormat('EEEE, d MMM').format(s)} · $count of ${DayScore.total} goals'
        '${done.isEmpty ? '' : ' (${done.map((t) => t.name).join(', ')})'}',
        style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
      );
    }
    final inMonth = widget.scores.entries.where((e) => e.key.year == month.year && e.key.month == month.month);
    final active = inMonth.where((e) => e.value.keepsStreak).length;
    final perfect = inMonth.where((e) => e.value.count == DayScore.total).length;
    final best = longestStreak({for (final e in inMonth) e.key: e.value});
    return Row(
      children: [
        Expanded(
          child: Text(
            '$active active · $perfect perfect · best run $best',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text('Less', style: text.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(width: 4),
        for (final c in AppColors.heat)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
          ),
        const SizedBox(width: 4),
        Text('More', style: text.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    style: IconButton.styleFrom(backgroundColor: onTap == null ? Colors.transparent : AppColors.background),
    icon: Icon(icon, color: onTap == null ? AppColors.textMuted : AppColors.textPrimary),
  );
}
