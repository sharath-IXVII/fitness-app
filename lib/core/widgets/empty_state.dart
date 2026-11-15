import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// What a page shows when it has nothing yet: an icon, a line saying what
/// will appear here and, where it helps, one button to get started.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
