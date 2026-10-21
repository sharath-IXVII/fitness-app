import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reminders.dart';
import '../../core/storage.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';

class WaterSettings {
  const WaterSettings({this.reminders = true, this.everyMinutes = 90});

  final bool reminders;
  final int everyMinutes;
}

class WaterSettingsNotifier extends Notifier<WaterSettings> {
  static const _onKey = 'water.remind.v1';
  static const _everyKey = 'water.every.v1';

  @override
  WaterSettings build() {
    final p = ref.read(sharedPrefsProvider);
    return WaterSettings(reminders: p.getBool(_onKey) ?? true, everyMinutes: p.getInt(_everyKey) ?? 90);
  }

  Future<void> set({bool? reminders, int? everyMinutes}) async {
    state = WaterSettings(reminders: reminders ?? state.reminders, everyMinutes: everyMinutes ?? state.everyMinutes);
    final p = ref.read(sharedPrefsProvider);
    await p.setBool(_onKey, state.reminders);
    await p.setInt(_everyKey, state.everyMinutes);
    if (state.reminders) await Reminders.requestPermission();
    await reschedule();
  }

  /// Water reminders run from wake-up to bedtime.
  Future<void> reschedule() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await Reminders.scheduleWater(
      from: profile.wakeTime,
      to: profile.sleepTime,
      everyMinutes: state.everyMinutes,
      enabled: state.reminders,
    );
  }
}

final waterSettingsProvider = NotifierProvider<WaterSettingsNotifier, WaterSettings>(WaterSettingsNotifier.new);

/// Last 7 days of water in ml (oldest first).
final weekWaterProvider = Provider<List<(DateTime, int)>>((ref) {
  final logs = ref.watch(dailyLogsProvider);
  final today = DateTime.now();
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        return (d, logs[d]?.waterMl ?? 0);
      }(),
  ];
});
