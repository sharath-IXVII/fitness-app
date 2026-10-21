import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Rounded bottom-sheet body with a grab handle, a title row and a
/// scrollable content area that stays above the keyboard.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child, this.action, this.footer});

  final String title;
  final Widget child;
  final Widget? action;
  final Widget? footer;

  static Future<T?> show<T>(BuildContext context, Widget sheet) => showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                    ?action,
                  ],
                ),
              ),
              Flexible(child: child),
              if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: footer),
            ],
          ),
        ),
      ),
    );
  }
}
