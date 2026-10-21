import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// White card used across the app. Optional [glow] tints the border to mark
/// a completed or active state.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.glow,
    this.blur = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: shape,
        color: AppColors.surface.withValues(alpha: blur ? 0.8 : 1),
        border: Border.all(color: glow?.withValues(alpha: 0.3) ?? AppColors.stroke),
        boxShadow: AppColors.softShadow(),
      ),
      child: child,
    );
    if (blur) {
      card = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: card),
      );
    }
    return card;
  }
}
