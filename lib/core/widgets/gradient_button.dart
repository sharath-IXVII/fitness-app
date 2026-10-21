import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 60,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.brandGradient : null,
          color: enabled ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: AppColors.lime.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: enabled ? Colors.black : AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, color: enabled ? Colors.black : AppColors.textMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
