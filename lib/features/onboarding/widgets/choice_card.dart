import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.emoji,
    this.color = AppColors.primary,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final leading = emoji != null
        ? Text(emoji!, style: const TextStyle(fontSize: 26))
        : Icon(icon, color: selected ? Colors.white : color, size: 24);

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(compact ? 16 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected ? color.withValues(alpha: 0.10) : AppColors.surface,
          border: Border.all(color: selected ? color : AppColors.stroke, width: selected ? 1.6 : 1),
          boxShadow: [if (selected) BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -6)],
        ),
        child: compact
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconBox(leading),
                    const SizedBox(height: 12),
                    Text(title, style: text.titleMedium, textAlign: TextAlign.center),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: text.bodySmall, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              )
            : Row(
                children: [
                  _iconBox(leading),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle!, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.check_circle_rounded, color: color),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _iconBox(Widget leading) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected && emoji == null ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(15),
    ),
    child: leading,
  );
}
