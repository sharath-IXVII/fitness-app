import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/launcher_icon.dart';
import '../../core/reminders.dart';
import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../progress/domain/progress.dart';
import '../progress/progress_providers.dart';
import '../alarm/app_permissions.dart';
import '../arcs/arc_providers.dart';
import '../friends/domain/friends.dart';
import '../friends/friends_providers.dart';
import '../myday/myday_providers.dart';
import '../profile/profile_providers.dart';
import '../steps/steps_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../training/training_providers.dart';
import '../training/workout_reminder.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _askPermissionsOnce();
      ref.read(stepsProvider.notifier).start();
      _replan();
      // The launcher icon follows the real arc (not a look being previewed).
      LauncherIcon.sync(ref.read(sharedPrefsProvider), ref.read(currentArcProvider).season);
      ref.read(myDayProvider.notifier).reschedule();
      final me = ref.read(myPublicProfileProvider);
      if (me != null) ref.read(friendsBackendProvider)?.syncProfile(me).catchError((_) {});
      _announce(ref.read(achievementsProvider));
    });
    _lifecycle = AppLifecycleListener(onResume: _replan);
  }

  late final AppLifecycleListener _lifecycle;

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Water and workout reminders are planned a week ahead and skip what's
  /// already done today, so they're re-planned whenever things change.
  void _replan() {
    ref.read(waterSettingsProvider.notifier).reschedule();
    ref.read(workoutReminderProvider.notifier).reschedule();
  }

  static const _permIntroKey = 'perm.intro.v1';

  /// Once, right after onboarding: explain and ask for notifications and
  /// alarms, so the wake-up alarm and reminders work from day one.
  Future<void> _askPermissionsOnce() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (!Reminders.supported || prefs.getBool(_permIntroKey) == true || !mounted) return;
    await prefs.setBool(_permIntroKey, true);
    if (await AppPermissions.allGranted() || !mounted) return;
    final text = Theme.of(context).textTheme;
    final allow = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 36),
              const SizedBox(height: 12),
              Text('Never miss a beat', style: text.headlineSmall),
              const SizedBox(height: 8),
              for (final line in [
                'Your wake-up alarm rings even when the app is closed',
                'Reminders for your routine, workouts and water',
                'The camera counts your reps; nothing is recorded or uploaded',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line, style: text.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Allow')),
              ),
              Center(
                child: TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
              ),
            ],
          ),
        ),
      ),
    );
    if (allow == true) await AppPermissions.requestAll();
  }

  static const _items = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Today'),
    (Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Workouts'),
    (Icons.view_timeline_outlined, Icons.view_timeline_rounded, 'My Day'),
    (Icons.alarm_outlined, Icons.alarm_rounded, 'Alarm'),
    (Icons.restaurant_outlined, Icons.restaurant_rounded, 'Diet'),
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
        // Snackbars with an action stay until tapped by default; this one
        // must not cover buttons such as a workout's Done.
        persist: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(achievementsProvider, (_, next) => _announce(next));
    // Re-plan reminders when today's workout or water goal changes, a
    // challenge moves on, or a new day starts.
    ref.listen(
      todayLogProvider.select((l) => (l.workoutDone, l.waterMl >= (ref.read(targetsProvider)?.waterMl ?? 0))),
      (_, _) {
        _replan();
      },
    );
    ref.listen(trainingProvider.select((t) => t.challenges), (_, _) => _replan());
    ref.listen(todayProvider, (_, _) => _replan());
    ref.listen(currentArcProvider, (_, next) => LauncherIcon.sync(ref.read(sharedPrefsProvider), next.season));
    // A finished challenge whose friendship didn't get saved (offline, app
    // closed): write it again. Safe to repeat.
    ref.listen(challengesProvider, (_, next) {
      final b = ref.read(friendsBackendProvider);
      final friends = {for (final f in ref.read(friendsListProvider).value ?? const []) f.uid};
      final uid = ref.read(friendsUidProvider);
      if (b == null || uid == null) return;
      for (final c in next.value ?? const <FriendChallenge>[]) {
        final other = c.otherUid(uid);
        if (c.status == ChallengeStatus.done && other != null && !friends.contains(other)) {
          b.ensureFriendship(c).catchError((_) {});
        }
      }
    });
    // Keep what friends see (name, badge, XP, streak) up to date.
    ref.listen(myPublicProfileProvider, (prev, next) {
      final b = ref.read(friendsBackendProvider);
      if (b != null && next != null && next != prev) b.syncProfile(next).catchError((_) {});
    });
    final index = shell.currentIndex;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
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
