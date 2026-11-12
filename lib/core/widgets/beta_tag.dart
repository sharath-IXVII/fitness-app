import '../i18n/i18n.dart';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small "BETA" pill for features that are still being improved. Shown
/// only where [visible] is set (today: Diet and food scanning, which learn
/// from users' corrections).
class BetaTag extends StatelessWidget {
  const BetaTag({super.key, this.visible = false});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        tr('BETA'),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.primary),
      ),
    );
  }
}

/// A short, honest note: these numbers are estimates.
class BetaNote extends StatelessWidget {
  const BetaNote({super.key, this.text = defaultText});

  static const defaultText =
      'Calories and nutrients are estimates from your photo. They work well for everyday tracking but may not be '
      'exact, so tap any dish to correct it.';

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(tr(text), style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
