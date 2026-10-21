import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder brand mark: a gradient squircle with an alarm-bolt glyph.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(color: AppColors.lime.withValues(alpha: 0.45), blurRadius: size * 0.5, spreadRadius: -size * 0.1),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.alarm_rounded, size: size * 0.6, color: Colors.black.withValues(alpha: 0.85)),
          Padding(
            padding: EdgeInsets.only(top: size * 0.06),
            child: Icon(Icons.bolt_rounded, size: size * 0.3, color: AppColors.lime),
          ),
        ],
      ),
    );
  }
}
