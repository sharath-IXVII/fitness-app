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
  const TimeWheel({super.key, required this.count, required this.value, required this.onChanged});

  final int count;
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

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall;
    return SizedBox(
      width: 96,
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
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < widget.count; i++) Center(child: Text(i.toString().padLeft(2, '0'), style: style)),
          ],
        ),
      ),
    );
  }
}
