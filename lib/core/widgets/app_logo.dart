import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder brand mark until the final logo is chosen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
            spreadRadius: -size * 0.1,
          ),
        ],
      ),
      child: Icon(Icons.alarm_on_rounded, size: size * 0.52, color: Colors.white),
    );
  }
}
