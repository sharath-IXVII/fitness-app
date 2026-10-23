import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Horizontal measuring-tape picker with a haptic tick on every step.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.unit,
    this.step = 1,
    this.decimals = 0,
    this.color,
  });

  final double min;
  final double max;
  final double value;
  final double step;
  final int decimals;
  final String unit;
  final Color? color;
  final ValueChanged<double> onChanged;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final FixedExtentScrollController _controller;

  int get _count => ((widget.max - widget.min) / widget.step).round() + 1;
  double _valueAt(int i) => widget.min + i * widget.step;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: ((widget.value - widget.min) / widget.step).round());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color => widget.color ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                    child: c,
                  ),
                ),
                child: Text(
                  widget.value.toStringAsFixed(widget.decimals),
                  key: ValueKey(widget.value),
                  style: text.displayLarge?.copyWith(fontSize: 76, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.unit, style: text.titleLarge?.copyWith(color: _color)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.2, 0.8, 1],
                ).createShader(r),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: 14,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 100,
                    perspective: 0.0001,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.selectionClick();
                      widget.onChanged(_valueAt(i));
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _count,
                      builder: (_, i) => RotatedBox(quarterTurns: 1, child: _tick(i)),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 4,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.6), blurRadius: 14)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tick(int i) {
    final major = i % 10 == 0;
    final mid = i % 5 == 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: major ? 2.4 : 1.6,
          height: major ? 44 : (mid ? 32 : 20),
          decoration: BoxDecoration(
            color: major ? AppColors.textSecondary : AppColors.textMuted,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (major) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 14,
            child: OverflowBox(
              maxWidth: 40,
              child: Text(
                _valueAt(i).toStringAsFixed(0),
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
