import '../../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../core/theme/app_colors.dart';

/// A short "do this, then this" card shown the first time someone opens a
/// screen. "Got it" hides it for good; it can be brought back from the
/// screen's help button.
class GuideCard extends ConsumerStatefulWidget {
  const GuideCard({super.key, required this.id, required this.title, required this.steps});

  /// Remembers that it was dismissed: `guide.<id>.v1`.
  final String id;
  final String title;
  final List<String> steps;

  @override
  ConsumerState<GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends ConsumerState<GuideCard> {
  late bool _hidden = ref.read(sharedPrefsProvider).getBool(_key) ?? false;

  String get _key => 'guide.${widget.id}.v1';

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title, style: text.titleSmall)),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, s) in widget.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s, style: text.bodyMedium)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ref.read(sharedPrefsProvider).setBool(_key, true);
                setState(() => _hidden = true);
              },
              child: Text(tr('Got it')),
            ),
          ),
        ],
      ),
    );
  }
}
