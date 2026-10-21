import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../progress/domain/progress.dart';
import '../progress/progress_providers.dart';
import '../steps/steps_providers.dart';
import '../water/water_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    // The shell only exists once the user is signed in and onboarded, so this
    // is where background services start: step tracking and water reminders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stepsProvider.notifier).start();
      ref.read(waterSettingsProvider.notifier).reschedule();
      _announce(ref.read(achievementsProvider));
    });
  }

  static const _items = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Today'),
    (Icons.view_timeline_outlined, Icons.view_timeline_rounded, 'My Day'),
    (Icons.alarm_outlined, Icons.alarm_rounded, 'Alarm'),
    (Icons.restaurant_outlined, Icons.restaurant_rounded, 'Diet'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

  static const _seenKey = 'achievements.seen.v1';

  /// Shows a quiet notice for achievements earned since the last check. The
  /// first time, everything already earned is marked seen without a notice.
  void _announce(Map<Achievement, DateTime> earned) {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getStringList(_seenKey);
    final names = earned.keys.map((a) => a.name).toList();
    if (seen == null) {
      prefs.setStringList(_seenKey, names);
      return;
    }
    final fresh = earned.keys.where((a) => !seen.contains(a.name)).toList();
    if (fresh.isEmpty) return;
    prefs.setStringList(_seenKey, {...seen, ...names}.toList());
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(fresh.first.icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fresh.length == 1
                    ? 'Achievement unlocked: ${fresh.first.title}'
                    : '${fresh.length} achievements unlocked',
              ),
            ),
          ],
        ),
        action: SnackBarAction(label: 'View', onPressed: () => context.push(Routes.achievements)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(achievementsProvider, (_, next) => _announce(next));
    final index = shell.currentIndex;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.stroke)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (final (i, item) in _items.indexed)
                  Expanded(
                    child: _NavItem(
                      icon: item.$1,
                      activeIcon: item.$2,
                      label: item.$3,
                      active: index == i,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        shell.goBranch(i, initialLocation: i == index);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Soft pill behind the active icon, as in Material 3.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: active ? 56 : 40,
              height: 30,
              decoration: BoxDecoration(
                color: active ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(active ? activeIcon : icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.textPrimary : AppColors.textTertiary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
