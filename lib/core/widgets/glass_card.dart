import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted card used across the app. Optional [glow] tints the border and
/// casts a soft coloured shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceHigh.withValues(alpha: blur ? 0.7 : 1),
            AppColors.surface.withValues(alpha: blur ? 0.6 : 1),
          ],
        ),
        border: Border.all(color: glow?.withValues(alpha: 0.35) ?? AppColors.stroke),
        boxShadow: [
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.18), blurRadius: 32, spreadRadius: -6),
        ],
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
