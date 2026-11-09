import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reminders.dart';
import '../../core/storage.dart';
import '../friends/friends_providers.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../streaks/domain/daily_log.dart';
import 'domain/team.dart';
import 'teams_backend.dart';

final teamsBackendProvider = Provider<TeamsBackend?>((ref) {
  final f = ref.watch(friendsBackendProvider);
  return f == null ? null : TeamsBackend(f.db);
});

final myTeamsProvider = StreamProvider<List<Team>>((ref) {
  final b = ref.watch(teamsBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return Stream.value(const []);
  return b.myTeams(uid);
});

final teamDaysProvider = StreamProvider.family<Map<String, Set<String>>, String>((ref, id) {
  final b = ref.watch(teamsBackendProvider);
  if (b == null) return Stream.value(const {});
  return b.days(id);
});

/// Nudges ("Ravi finished today's goals. What are you doing?"): on unless
/// the user turns them off.
class NudgesNotifier extends Notifier<bool> {
  static const key = 'teams.nudges.v1';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(key) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPrefsProvider).setBool(key, on);
  }
}

final nudgesProvider = NotifierProvider<NudgesNotifier, bool>(NudgesNotifier.new);

/// Checks this user in to each team once their day keeps the streak, and
/// nudges them (once a day) when teammates are done and they aren't.
final teamSyncProvider = Provider<void>((ref) {
  void sync() {
    final b = ref.read(teamsBackendProvider), uid = ref.read(friendsUidProvider);
    final t = ref.read(targetsProvider);
    if (b == null || uid == null || t == null) return;
    final today = clock.now();
    final key = teamDayKey(today);
    final prefs = ref.read(sharedPrefsProvider);
    final done = DayScore.of(ref.read(todayLogProvider), t).keepsStreak;
    for (final team in ref.read(myTeamsProvider).value ?? const <Team>[]) {
      final days = ref.read(teamDaysProvider(team.id)).value ?? const {};
      final todayDone = days[key] ?? const <String>{};
      if (done && !todayDone.contains(uid)) {
        b.checkIn(team.id, uid, today).catchError((_) {});
      }
      // A nudge, once a day per team, when a teammate is done and I'm not.
      final others = todayDone.where((u) => u != uid).toList();
      final nudgeKey = 'teams.nudged.${team.id}.$key';
      if (!done && others.isNotEmpty && ref.read(nudgesProvider) && prefs.getBool(nudgeKey) != true) {
        prefs.setBool(nudgeKey, true);
        final name = team.names[others.first] ?? 'A teammate';
        Reminders.nudgeNow(
          '$name finished today\'s goals 💪',
          'What are you doing? Keep the ${team.name} streak alive.',
        );
      }
    }
  }

  // Re-run whenever today's log, the teams, or any team's days change.
  ref.watch(todayLogProvider);
  for (final t in ref.watch(myTeamsProvider).value ?? const <Team>[]) {
    ref.watch(teamDaysProvider(t.id));
  }
  Future.microtask(sync);
});
