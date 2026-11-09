import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../friends/friends_backend.dart';
import '../share/share_card.dart';
import '../report/report_providers.dart';
import '../clubs/clubs_providers.dart';
import '../../core/cloud_backup.dart';
import '../../core/reminders.dart';
import '../../core/home_widget_sync.dart';
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
      ref.read(myDayProvider.notifier).reschedule();
      final me = ref.read(myPublicProfileProvider);
      if (me != null) ref.read(friendsBackendProvider)?.syncProfile(me).catchError((_) {});
      ref.read(badgeVaultProvider.notifier).merge(ref.read(computedBadgesProvider));
      _announce(ref.read(achievementsProvider));
      ref.read(cloudBackupProvider).schedule(after: const Duration(seconds: 5));
      ref.read(reportSettingsProvider.notifier).reschedule();
      // Opened by tapping a notification: go to what it's about.
      Reminders.onOpen = _openFromNotification;
      if (Reminders.pendingOpen case final type?) {
        Reminders.pendingOpen = null;
        _openFromNotification(type);
      }
    });
    _lifecycle = AppLifecycleListener(onResume: _replan, onPause: () => ref.read(cloudBackupProvider).push());
  }

  late final AppLifecycleListener _lifecycle;

  void _openFromNotification(String type) {
    if (!mounted) return;
    switch (type) {
      case 'report':
        context.push(Routes.dailyReport);
      case 'clubs':
        context.push(Routes.clubs);
    }
  }

  @override
  void dispose() {
    Reminders.onOpen = null;
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
  static const _streakSeenKey = 'streak.celebrated.v1';

  void _celebrateStreak(int days) {
    if (!streakMilestones.contains(days) || !mounted) return;
    final prefs = ref.read(sharedPrefsProvider);
    final done = prefs.getStringList(_streakSeenKey) ?? const [];
    // Once per milestone per streak (a new streak can celebrate again).
    final id = '$days@${DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10)}';
    if (done.contains(id)) return;
    prefs.setStringList(_streakSeenKey, [...done, id]);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔥 $days-day streak! Keep it going.'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => context.push(Routes.shareCard, extra: ShareCardData.streak(days)),
        ),
        persist: false,
      ),
    );
  }

  /// Shows a quiet notice for achievements earned since the last check. The
  /// first time, everything already earned is marked seen without a notice.
  void _announce(Map<BadgeKey, DateTime> earned) {
    final prefs = ref.read(sharedPrefsProvider);
    final seen = prefs.getStringList(_seenKey);
    final names = earned.keys.map(badgeId).toList();
    if (seen == null) {
      prefs.setStringList(_seenKey, names);
      return;
    }
    final fresh = earned.keys.where((a) => !seen.contains(badgeId(a))).toList();
    if (fresh.isEmpty) return;
    prefs.setStringList(_seenKey, {...seen, ...names}.toList());
    HapticFeedback.mediumImpact();
    final info = fresh.first.kind.info(fresh.first.set);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(fresh.first.kind.icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fresh.length == 1
                    ? 'Achievement unlocked: ${fresh.first.kind.info(fresh.first.set).title}'
                    : '${fresh.length} achievements unlocked',
              ),
            ),
          ],
        ),
        // One badge: share it. Several: see them all.
        action: fresh.length == 1
            ? SnackBarAction(
                label: 'Share',
                onPressed: () => context.push(
                  Routes.shareCard,
                  extra: ShareCardData.badge(title: info.title, description: info.description),
                ),
              )
            : SnackBarAction(label: 'View', onPressed: () => context.push(Routes.achievements)),
        // Snackbars with an action stay until tapped by default; this one
        // must not cover buttons such as a workout's Done.
        persist: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Progress is backed up to the account shortly after it changes.
    final backup = ref.read(cloudBackupProvider);
    ref.listen(dailyLogsProvider, (_, _) => backup.schedule());
    ref.listen(profileProvider, (_, _) => backup.schedule());
    ref.listen(badgeVaultProvider, (_, _) => backup.schedule());
    ref.listen(waterGoalProvider, (_, _) => backup.schedule());
    ref.listen(computedBadgesProvider, (_, next) => ref.read(badgeVaultProvider.notifier).merge(next));
    ref.listen(achievementsProvider, (_, next) => _announce(next));
    // Streak milestones (3, 7, 14, 30 … days): offer a share card, once each.
    ref.listen(streakProvider.select((s) => s.current), (_, days) => _celebrateStreak(days));
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
    // Invite rewards: XP for each friend who joined with this user's code.
    ref.listen(inviteesProvider, (_, next) {
      for (final uid in next.value ?? const <String>[]) {
        ref.read(clubXpProvider.notifier).award('ref-$uid', FriendsBackend.inviteXp);
      }
    });
    // Keeps the home screen widget up to date.
    ref.watch(homeWidgetSyncProvider);
    // Club challenge reminders on this phone (no server needed).
    ref.watch(clubReminderPlannerProvider);
    // XP from finished challenges (50 each, up to 3 a week).
    ref.listen(
      challengesProvider,
      (_, next) => ref.read(bonusXpProvider.notifier).set(challengeBonusXp(next.value ?? const [])),
    );
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
                      beta: item.$3 == 'Diet',
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
    this.beta = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final bool beta;
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
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(active ? activeIcon : icon, size: 22, color: color),
                  // A small marker while the diet section is in beta.
                  if (beta)
                    Positioned(
                      top: 0,
                      right: active ? 2 : -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              // Inter like the rest of the app, not the phone's default font.
              style: GoogleFonts.inter(
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
