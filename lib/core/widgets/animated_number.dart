import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Counts up to [value] when first shown or when the value changes.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber(
    this.value, {
    super.key,
    this.style,
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 1200),
  });

  final num value;
  final TextStyle? style;
  final String suffix;
  final int decimals;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPatternDigits(decimalDigits: decimals);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => Text('${format.format(v)}$suffix', style: style),
    );
  }
}
