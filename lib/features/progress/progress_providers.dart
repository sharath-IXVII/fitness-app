import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/progress.dart';

/// Badges worked out from the day logs as they stand now.
final computedBadgesProvider = Provider<Map<BadgeKey, DateTime>>((ref) {
  final t = ref.watch(targetsProvider);
  return t == null ? const {} : earnedAchievements(ref.watch(dailyLogsProvider), t);
});

const _vaultKey = 'badges.earned.v1';

/// Every badge ever earned, kept for good. A badge is hard work, so it must
/// never disappear when a target changes later (a higher water goal in a hot
/// season, say), and it is what gets backed up to the cloud.
class BadgeVault extends Notifier<Map<BadgeKey, DateTime>> {
  @override
  Map<BadgeKey, DateTime> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_vaultKey);
    if (raw == null) return const {};
    try {
      return _decode(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const {};
    }
  }

  static Map<BadgeKey, DateTime> _decode(Map<String, dynamic> json) {
    final out = <BadgeKey, DateTime>{};
    for (final e in json.entries) {
      final key = parseBadgeId(e.key);
      final date = DateTime.tryParse('${e.value}');
      if (key != null && date != null) out[key] = DateTime(date.year, date.month, date.day);
    }
    return out;
  }

  /// Adds badges not stored yet, and keeps the earliest date for those that
  /// are. Never removes anything.
  Future<void> merge(Map<BadgeKey, DateTime> earned) async {
    final next = {...state};
    var changed = false;
    for (final e in earned.entries) {
      final old = next[e.key];
      if (old == null || e.value.isBefore(old)) {
        next[e.key] = e.value;
        changed = true;
      }
    }
    if (!changed) return;
    state = next;
    await ref
        .read(sharedPrefsProvider)
        .setString(_vaultKey, jsonEncode({for (final e in next.entries) badgeId(e.key): e.value.toIso8601String()}));
  }
}

final badgeVaultProvider = NotifierProvider<BadgeVault, Map<BadgeKey, DateTime>>(BadgeVault.new);

/// Every badge earned in any set: the stored ones plus anything new.
final _allEarnedProvider = Provider<Map<BadgeKey, DateTime>>((ref) {
  final all = {...ref.watch(badgeVaultProvider)};
  for (final e in ref.watch(computedBadgesProvider).entries) {
    final old = all[e.key];
    if (old == null || e.value.isBefore(old)) all[e.key] = e.value;
  }
  return all;
});

/// Badge sets finished so far (each pays a XP bonus and opens the next).
final completedSetsProvider = Provider<int>((ref) => completedSets(ref.watch(_allEarnedProvider).keys));

/// The badges that count: those in finished sets and in the set being worked
/// on. Harder sets stay locked (their badges are still remembered, and show
/// up the moment the set before is finished).
final achievementsProvider = Provider<Map<BadgeKey, DateTime>>((ref) {
  final open = ref.watch(completedSetsProvider) + 1;
  return {
    for (final e in ref.watch(_allEarnedProvider).entries)
      if (e.key.set <= open) e.key: e.value,
  };
});

/// XP that does not come from the daily logs: finished challenges. The app
/// shell keeps it current from the challenges list.
class BonusXp extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final bonusXpProvider = NotifierProvider<BonusXp, int>(BonusXp.new);

/// Level from activity XP, the bonus for every finished badge set, and XP
/// from finished challenges.
final levelProvider = Provider<Level>((ref) {
  final int xp =
      totalXp(ref.watch(dayScoresProvider)) +
      setBonusXp(ref.watch(completedSetsProvider)) +
      ref.watch(bonusXpProvider);
  return Level.of(xp);
});

final weekReportProvider = Provider<WeekReport?>((ref) {
  final t = ref.watch(targetsProvider);
  return t == null ? null : WeekReport.of(ref.watch(dailyLogsProvider), t, DateTime.now());
});
