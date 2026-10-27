import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

// Small form controls shared by the alarm and My Day editors.

class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.93,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
    ),
  );
}

class DayDot extends StatelessWidget {
  const DayDot({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.88,
    child: AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.surfaceHigh,
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
        ),
      ),
    ),
  );
}

class SettingToggle extends StatelessWidget {
  const SettingToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;

  /// Null shows the toggle disabled.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: value ? AppColors.primary : AppColors.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                if (subtitle != null) Text(subtitle!, style: text.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged == null
                ? null
                : (v) {
                    HapticFeedback.selectionClick();
                    onChanged!(v);
                  },
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Segmented control with a sliding highlight.
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({super.key, required this.options, required this.index, required this.onChanged});

  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + 2 * index / (options.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / options.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppColors.softShadow(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, o) in options.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: Center(
                      child: Text(
                        o,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i == index ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TimeWheel extends StatefulWidget {
  const TimeWheel({
    super.key,
    required this.count,
    required this.value,
    required this.onChanged,
    this.label,
    this.width = 96,
    this.loop = true,
  });

  final int count;
  final String Function(int)? label;
  final double width;
  final bool loop;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late final _controller = FixedExtentScrollController(initialItem: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _items(TextStyle? style) => [
    for (var i = 0; i < widget.count; i++)
      Center(child: Text(widget.label?.call(i) ?? i.toString().padLeft(2, '0'), style: style)),
  ];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall;
    return SizedBox(
      width: widget.width,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 56,
        perspective: 0.004,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.3,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          widget.onChanged(i % widget.count);
        },
        childDelegate: widget.loop
            ? ListWheelChildLoopingListDelegate(children: _items(style))
            : ListWheelChildListDelegate(children: _items(style)),
      ),
    );
  }
}

/// Hour, minute and AM/PM wheels, so nobody has to read "15" as 3 PM.
class ClockWheels extends StatelessWidget {
  const ClockWheels({super.key, required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pm = time.hour >= 12;
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    int to24(int h12, bool isPm) => (h12 % 12) + (isPm ? 12 : 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shows 12, 1, 2 ... 11; the wheel index is the hour on a 12-hour clock.
        TimeWheel(
          count: 12,
          value: time.hour % 12,
          label: (i) => (i == 0 ? 12 : i).toString(),
          onChanged: (i) => onChanged(TimeOfDay(hour: to24(i, pm), minute: time.minute)),
        ),
        Text(':', style: text.displaySmall),
        TimeWheel(
          count: 60,
          value: time.minute,
          onChanged: (v) => onChanged(TimeOfDay(hour: time.hour, minute: v)),
        ),
        const SizedBox(width: 8),
        TimeWheel(
          count: 2,
          value: pm ? 1 : 0,
          width: 84,
          loop: false,
          label: (i) => i == 0 ? 'AM' : 'PM',
          onChanged: (i) => onChanged(TimeOfDay(hour: to24(hour12, i == 1), minute: time.minute)),
        ),
      ],
    );
  }
}
