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

  Future<void> update(DailyLog Function(DailyLog) change) async {
    final next = change(today());
    state = {...state, next.date: next};
    await ref.read(sharedPrefsProvider).setString('$_prefix${_keyFormat.format(next.date)}', jsonEncode(next.toJson()));
  }

  Future<void> addWater(int ml) => update((l) => l.copyWith(waterMl: l.waterMl + ml));

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

final streakProvider = Provider<({int current, int longest})>((ref) {
  final scores = ref.watch(dayScoresProvider);
  return (current: currentStreak(scores, DateTime.now()), longest: longestStreak(scores));
});
