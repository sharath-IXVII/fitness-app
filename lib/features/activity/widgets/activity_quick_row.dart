import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../clubs/domain/club_challenge.dart';

/// Run · Walk · Cycle · Skipping, one tap to start.
class ActivityQuickRow extends StatelessWidget {
  const ActivityQuickRow({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 30),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(tr(label), style: text.titleSmall, maxLines: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        for (final k in ActivityKind.values) ...[
          tile(k.icon, k.label, () => context.push(Routes.activity, extra: k)),
          const SizedBox(width: 10),
        ],
        tile(Icons.sports_gymnastics_rounded, 'Skipping', () => context.push(Routes.skipping)),
      ],
    );
  }
}
