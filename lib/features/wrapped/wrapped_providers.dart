import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../arcs/arc_providers.dart';
import '../arcs/domain/arc.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/arc_wrapped.dart';

/// Meal names logged per day (from the diet log on this phone).
Map<DateTime, List<String>> _mealNames(Ref ref) {
  final prefs = ref.read(sharedPrefsProvider);
  final out = <DateTime, List<String>>{};
  for (final k in prefs.getKeys().where((k) => k.startsWith('meals.v1.'))) {
    final day = DateTime.tryParse(k.substring('meals.v1.'.length));
    if (day == null) continue;
    try {
      out[day] = [
        for (final e in jsonDecode(prefs.getString(k) ?? '[]') as List<dynamic>)
          if ((e as Map<String, dynamic>)['name'] case final String n) n,
      ];
    } catch (_) {}
  }
  return out;
}

/// The Wrapped story for [period].
final arcWrappedProvider = Provider.family<ArcWrapped, ArcPeriod>((ref, period) {
  final tier = ref.watch(arcBadgesProvider).where((b) => b.$1 == period).map((b) => b.$2).firstOrNull;
  return ArcWrapped.of(
    period,
    ref.watch(dailyLogsProvider),
    ref.watch(dayScoresProvider),
    mealNames: _mealNames(ref),
    tier: tier,
  );
});

/// The Arc that just ended, for 14 days after it ends, if the user was active
/// in it.
final freshWrappedProvider = Provider<ArcPeriod?>((ref) {
  final today = ref.watch(todayProvider);
  final now = ref.watch(currentArcProvider);
  if (today.difference(now.start).inDays > 14) return null;
  final last = now.previous;
  return ref.watch(arcWrappedProvider(last)).isEmpty ? null : last;
});
