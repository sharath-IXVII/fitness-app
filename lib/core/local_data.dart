import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alarm/alarm_providers.dart';
import '../features/alarm/strict_mode.dart';
import '../features/arcs/arc_providers.dart';
import '../features/diet/diet_providers.dart';
import '../features/myday/myday_providers.dart';
import '../features/profile/profile_providers.dart';
import '../features/progress/progress_providers.dart';
import '../features/steps/steps_providers.dart';
import '../features/streaks/daily_log_providers.dart';
import '../features/training/training_providers.dart';
import '../features/training/workout_reminder.dart';
import '../features/water/water_providers.dart';
import '../features/workout/routine_providers.dart';
import 'photo_store.dart';
import 'reminders.dart';
import 'storage.dart';

/// Everything FitArc keeps on the phone, and wiping it.
///
/// Lives in a (never disposed) provider so a wipe can finish even after the
/// screen that started it is gone, e.g. once sign-out sends the user back
/// to the sign-in screen.
class LocalData {
  LocalData(this._ref);

  final Ref _ref;

  /// Which account this phone's data belongs to.
  static const ownerKey = 'owner.uid.v1';

  /// Sign-in state is the sign-in service's business, not ours.
  static bool _keep(String key) => key.startsWith('auth.');

  /// Clears every alarm, reminder, photo and stored record on this phone.
  Future<void> wipe() async {
    final prefs = _ref.read(sharedPrefsProvider);
    // System alarms, reminders and photos are cancelled alongside; stored
    // data is cleared regardless of how long those take.
    final cleanup = Future.wait([
      _ref.read(alarmsProvider.notifier).clearAll().catchError((Object e) => debugPrint('wipe alarms: $e')),
      StrictMode.release(prefs).catchError((_) {}),
      Reminders.cancelAll(),
      PhotoStore.clearAll().catchError((_) {}),
    ]);
    for (final k in prefs.getKeys().where((k) => !_keep(k)).toList()) {
      await prefs.remove(k);
    }
    for (final p in [
      profileProvider,
      dailyLogsProvider,
      alarmsProvider,
      myDayProvider,
      doneTodayProvider,
      myDayRemindersProvider,
      mealLogProvider,
      myFoodsProvider,
      weightLogProvider,
      weightGoalProvider,
      trainingProvider,
      routinesProvider,
      waterSettingsProvider,
      workoutReminderProvider,
      stepsProvider,
      badgeVaultProvider,
      waterGoalProvider,
    ]) {
      _ref.invalidate(p);
    }
    _ref.invalidate(firstUseProvider);
    await cleanup.timeout(const Duration(seconds: 10), onTimeout: () => const []);
  }

  /// Called when someone signs in. If this phone's data belongs to a
  /// different account, it's wiped first so nobody sees someone else's data
  /// (or shares it with their friends).
  Future<void> claimFor(String uid) async {
    final prefs = _ref.read(sharedPrefsProvider);
    final owner = prefs.getString(ownerKey);
    if (owner != null && owner != uid) await wipe();
    await prefs.setString(ownerKey, uid);
  }
}

final localDataProvider = Provider<LocalData>(LocalData.new);
