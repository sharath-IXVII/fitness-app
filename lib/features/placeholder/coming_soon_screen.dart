import '../../core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/widgets/page_background.dart';

/// Temporary tab body for modules that land in later phases.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PageBackground(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, size: 44, color: color),
                ),
                const SizedBox(height: 28),
                Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(subtitle, style: text.bodyMedium?.copyWith(height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tr('Coming next'), style: text.labelMedium?.copyWith(color: color)),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
          ),
        ),
      ),
    );
  }
}
