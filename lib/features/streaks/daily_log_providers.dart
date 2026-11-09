import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/storage.dart';
import '../profile/profile_providers.dart';
import 'domain/daily_log.dart';

const _prefix = 'log.v1.';
final _keyFormat = DateFormat('yyyy-MM-dd');

/// All stored day logs, keyed by date. Phase 1 keeps them in shared
/// preferences; a proper local database replaces this once routines and
/// meals add more data.
class DailyLogsNotifier extends Notifier<Map<DateTime, DailyLog>> {
  @override
  Map<DateTime, DailyLog> build() {
    final prefs = ref.read(sharedPrefsProvider);
    final logs = <DateTime, DailyLog>{};
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      final date = _keyFormat.tryParse(key.substring(_prefix.length));
      final raw = prefs.getString(key);
      if (date == null || raw == null) continue;
      logs[date] = DailyLog.fromJson(date, jsonDecode(raw) as Map<String, dynamic>);
    }
    return logs;
  }

  DailyLog today() {
    final d = dayOnly(DateTime.now());
    return state[d] ?? DailyLog(date: d);
  }

  /// Changes today's log (or [date]'s). Re-reads storage first: notification
  /// buttons ("Yes, I had a glass") write from a background isolate, and
  /// building on a stale copy would erase what they added.
  Future<void> update(DailyLog Function(DailyLog) change, {DateTime? date}) async {
    final d = dayOnly(date ?? DateTime.now());
    final prefs = ref.read(sharedPrefsProvider);
    final key = '$_prefix${_keyFormat.format(d)}';
    try {
      await prefs.reload();
    } catch (_) {}
    final raw = prefs.getString(key);
    final current = raw == null
        ? (state[d] ?? DailyLog(date: d))
        : DailyLog.fromJson(d, jsonDecode(raw) as Map<String, dynamic>);
    final next = change(current);
    state = {...state, d: next};
    await prefs.setString(key, jsonEncode(next.toJson()));
  }

  /// Adds (or, with a negative [ml], undoes) water; never drops below zero.
  Future<void> addWater(int ml) => update((l) => l.copyWith(waterMl: (l.waterMl + ml).clamp(0, 20000)));

  Future<void> clearAll() async {
    final prefs = ref.read(sharedPrefsProvider);
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
    state = {};
  }
}

final dailyLogsProvider = NotifierProvider<DailyLogsNotifier, Map<DateTime, DailyLog>>(DailyLogsNotifier.new);

final todayLogProvider = Provider<DailyLog>((ref) {
  final d = dayOnly(DateTime.now());
  return ref.watch(dailyLogsProvider)[d] ?? DailyLog(date: d);
});

final dayScoresProvider = Provider<Map<DateTime, DayScore>>((ref) {
  final targets = ref.watch(targetsProvider);
  if (targets == null) return const {};
  return ref.watch(dailyLogsProvider).map((d, log) => MapEntry(d, DayScore.of(log, targets)));
});

/// The streak, with streak freezes covering missed days.
final streakFreezeProvider = Provider<({int current, int longest, int freezes, Set<DateTime> frozen})>(
  (ref) => streakWithFreezes(ref.watch(dayScoresProvider), DateTime.now()),
);

final streakProvider = Provider<({int current, int longest})>((ref) {
  final s = ref.watch(streakFreezeProvider);
  return (current: s.current, longest: s.longest);
});
