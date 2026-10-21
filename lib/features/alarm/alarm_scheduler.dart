import 'dart:convert';
import 'dart:io' show Platform;

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme/app_colors.dart';
import '../workout/domain/routine.dart';
import 'domain/workout_alarm.dart';

/// What a ringing alarm wants the user to do.
class RingInfo {
  const RingInfo({required this.alarmId, required this.routineId, required this.label});

  final int alarmId;
  final String routineId;
  final String label;

  String toPayload() => jsonEncode({'alarm': alarmId, 'routine': routineId, 'label': label});

  static RingInfo fromSettings(AlarmSettings s) {
    try {
      final j = jsonDecode(s.payload ?? '') as Map<String, dynamic>;
      return RingInfo(alarmId: j['alarm'] as int, routineId: j['routine'] as String, label: j['label'] as String);
    } catch (_) {
      return RingInfo(alarmId: s.id, routineId: Routine.beginner.id, label: 'Workout alarm');
    }
  }
}

/// Thin wrapper over the native alarm plugin.
///
/// Alarms are configured so they can't be silenced from outside the app:
/// no stop button, swiping the notification doesn't stop them, and killing
/// the app doesn't either. The only way out is finishing the workout (or the
/// deliberate emergency stop on the ring screen).
abstract final class AlarmScheduler {
  /// Re-rings if the user leaves a workout or stops moving.
  static const watchdogId = 9999;
  static const idleTimeout = Duration(seconds: 90);

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> init() async {
    if (!supported) return;
    await Alarm.init();
  }

  static Stream<List<RingInfo>> get ringing => supported
      ? Alarm.ringing.map((set) => [for (final a in set.alarms) RingInfo.fromSettings(a)])
      : const Stream.empty();

  static List<RingInfo> get ringingNow =>
      supported ? [for (final a in Alarm.ringing.value.alarms) RingInfo.fromSettings(a)] : const [];

  static AlarmSettings _settings({
    required int id,
    required DateTime at,
    required RingInfo info,
    required String body,
  }) => AlarmSettings(
    id: id,
    dateTime: at,
    assetAudioPath: 'assets/sounds/alarm.wav',
    loopAudio: true,
    vibrate: true,
    warningNotificationOnKill: Platform.isIOS,
    androidFullScreenIntent: true,
    androidStopAlarmOnTermination: false,
    payload: info.toPayload(),
    volumeSettings: VolumeSettings.fade(volume: 0.9, fadeDuration: const Duration(seconds: 6), volumeEnforced: true),
    notificationSettings: NotificationSettings(
      title: info.label,
      body: body,
      iconColor: AppColors.primary,
      androidStopAlarmOnDismiss: false,
    ),
  );

  /// Makes the native schedule match [alarms]. Alarms that are ringing right
  /// now are left alone so a sync never silences them.
  static Future<void> sync(List<WorkoutAlarm> alarms, List<Routine> routines) async {
    if (!supported) return;
    final ringingIds = Alarm.ringing.value.alarms.map((a) => a.id).toSet();
    final now = DateTime.now();
    final wanted = <int>{};

    for (final a in alarms) {
      if (ringingIds.contains(a.id)) {
        wanted.add(a.id);
        continue;
      }
      if (!a.enabled) {
        await Alarm.stop(a.id);
        continue;
      }
      wanted.add(a.id);
      final routine = routines.firstWhere((r) => r.id == a.routineId, orElse: () => Routine.beginner);
      await Alarm.set(
        alarmSettings: _settings(
          id: a.id,
          at: a.nextOccurrence(now),
          info: RingInfo(alarmId: a.id, routineId: routine.id, label: a.label),
          body: 'Finish your ${routine.name.toLowerCase()} routine to stop the alarm',
        ),
      );
    }

    // Drop anything scheduled for alarms that no longer exist.
    for (final s in await Alarm.getAlarms()) {
      if (s.id <= WorkoutAlarm.maxUserId && !wanted.contains(s.id)) await Alarm.stop(s.id);
    }
  }

  /// (Re)arms the idle watchdog [idleTimeout] from now.
  static Future<void> armWatchdog(RingInfo info) async {
    if (!supported) return;
    await Alarm.set(
      alarmSettings: _settings(
        id: watchdogId,
        at: DateTime.now().add(idleTimeout),
        info: info,
        body: "You stopped moving — finish your workout to silence this",
      ),
    );
  }

  static Future<void> stop(int id) async {
    if (!supported) return;
    await Alarm.stop(id);
  }

  static Future<bool> isRinging(int id) async => supported && await Alarm.isRinging(id);
}
