import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small "BETA" pill for features that are still being improved.
class BetaTag extends StatelessWidget {
  const BetaTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Beta',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
        ),
        child: Text(
          'BETA',
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.amber),
        ),
      ),
    );
  }
}

/// A short, honest note under a beta feature's heading.
class BetaNote extends StatelessWidget {
  const BetaNote({super.key, this.text = defaultText});

  static const defaultText =
      'Diet is in beta. Food recognition and calorie estimates can be off, so please check each item and '
      'correct it. We are improving it.';

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
