import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/progress.dart';

final levelProvider = Provider<Level>((ref) => Level.of(totalXp(ref.watch(dayScoresProvider))));

final achievementsProvider = Provider<Map<Achievement, DateTime>>((ref) {
  final t = ref.watch(targetsProvider);
  return t == null ? const {} : earnedAchievements(ref.watch(dailyLogsProvider), t);
});

final weekReportProvider = Provider<WeekReport?>((ref) {
  final t = ref.watch(targetsProvider);
  return t == null ? null : WeekReport.of(ref.watch(dailyLogsProvider), t, DateTime.now());
});
