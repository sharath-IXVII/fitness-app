import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reminders.dart';
import '../../core/storage.dart';
import '../clubs/clubs_providers.dart';
import '../diet/diet_providers.dart';
import '../profile/profile_providers.dart';
import '../snaps/snaps_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/daily_report.dart';

/// Today's report, or null before the profile exists.
final dailyReportProvider = Provider<DailyReport?>((ref) {
  final t = ref.watch(targetsProvider);
  if (t == null) return null;
  final log = ref.watch(todayLogProvider);
  final day = log.date;
  bool today(DateTime d) => d.year == day.year && d.month == day.month && d.day == day.day;
  final clubKm = ref
      .watch(runReportsProvider)
      .where((r) => today(r.finishedAt))
      .fold(0.0, (a, r) => a + r.distanceM / 1000);
  return DailyReport.of(
    log,
    t,
    kcalEaten: ref.watch(mealTotalsProvider).kcal,
    snaps: ref.watch(todaySnapsProvider).length,
    clubKm: clubKm,
    streak: ref.watch(streakProvider).current,
  );
});

/// The evening report reminder: on by default at 9:00 PM.
class ReportSettings {
  const ReportSettings({this.enabled = true, this.minute = 21 * 60});

  final bool enabled;
  final int minute;
}

class ReportSettingsNotifier extends Notifier<ReportSettings> {
  static const key = 'report.daily.v1';

  @override
  ReportSettings build() {
    try {
      final j = jsonDecode(ref.read(sharedPrefsProvider).getString(key) ?? '{}') as Map<String, dynamic>;
      return ReportSettings(enabled: j['on'] as bool? ?? true, minute: (j['m'] as num?)?.toInt() ?? 21 * 60);
    } catch (_) {
      return const ReportSettings();
    }
  }

  Future<void> set({bool? enabled, int? minute}) async {
    state = ReportSettings(enabled: enabled ?? state.enabled, minute: minute ?? state.minute);
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode({'on': state.enabled, 'm': state.minute}));
    await reschedule();
  }

  Future<void> reschedule() => Reminders.scheduleDailyReport(minuteOfDay: state.minute, enabled: state.enabled);
}

final reportSettingsProvider = NotifierProvider<ReportSettingsNotifier, ReportSettings>(ReportSettingsNotifier.new);
