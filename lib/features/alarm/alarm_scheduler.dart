import 'dart:convert';
import 'dart:io' show Platform;

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme/app_colors.dart';
import '../workout/domain/routine.dart';
import 'domain/workout_alarm.dart';

/// What a ringing alarm wants the user to do, plus the sound settings
/// needed to re-ring it (snooze, watchdog) the same way.
class RingInfo {
  const RingInfo({
    required this.alarmId,
    required this.routineId,
    required this.label,
    this.nativeId,
    this.snoozesLeft = 0,
    this.snoozeMinutes = 5,
    this.hardMode = false,
    this.strict = false,
    this.challenge = AlarmChallenge.workout,
    this.level = ChallengeLevel.medium,
    this.sound = AlarmSound.sunrise,
    this.volume = 0.9,
    this.fadeIn = true,
    this.vibrate = true,
  });

  factory RingInfo.forAlarm(WorkoutAlarm a, String routineId) => RingInfo(
    alarmId: a.id,
    routineId: routineId,
    label: a.label,
    snoozesLeft: a.allowedSnoozes,
    snoozeMinutes: a.snoozeMinutes,
    hardMode: a.noEscape,
    strict: a.strict,
    challenge: a.challenge,
    level: a.level,
    sound: a.sound,
    volume: a.volume,
    fadeIn: a.fadeIn,
    vibrate: a.vibrate,
  );

  /// The user alarm this ring belongs to.
  final int alarmId;

  /// The id actually ringing natively (the alarm itself, a snooze or the watchdog).
  final int? nativeId;
  final String routineId;
  final String label;
  final int snoozesLeft;
  final int snoozeMinutes;
  final bool hardMode;
  final bool strict;
  final AlarmChallenge challenge;
  final ChallengeLevel level;
  final AlarmSound sound;
  final double volume;
  final bool fadeIn;
  final bool vibrate;

  RingInfo copyWith({int? snoozesLeft}) => RingInfo(
    alarmId: alarmId,
    routineId: routineId,
    label: label,
    nativeId: nativeId,
    snoozesLeft: snoozesLeft ?? this.snoozesLeft,
    snoozeMinutes: snoozeMinutes,
    hardMode: hardMode,
    strict: strict,
    challenge: challenge,
    level: level,
    sound: sound,
    volume: volume,
    fadeIn: fadeIn,
    vibrate: vibrate,
  );

  String toPayload() => jsonEncode({
    'alarm': alarmId,
    'routine': routineId,
    'label': label,
    'snoozes': snoozesLeft,
    'snoozeMin': snoozeMinutes,
    'hard': hardMode,
    'strict': strict,
    'challenge': challenge.name,
    'level': level.name,
    'sound': sound.name,
    'volume': volume,
    'fade': fadeIn,
    'vibrate': vibrate,
  });

  static RingInfo fromSettings(AlarmSettings s) =>
      fromPayload(s.payload, nativeId: s.id) ??
      RingInfo(alarmId: s.id, nativeId: s.id, routineId: Routine.beginner.id, label: 'Workout alarm');

  static RingInfo? fromPayload(String? payload, {int? nativeId}) {
    try {
      final j = jsonDecode(payload ?? '') as Map<String, dynamic>;
      return RingInfo(
        alarmId: j['alarm'] as int,
        nativeId: nativeId,
        routineId: j['routine'] as String,
        label: j['label'] as String,
        snoozesLeft: j['snoozes'] as int? ?? 0,
        snoozeMinutes: j['snoozeMin'] as int? ?? 5,
        hardMode: j['hard'] as bool? ?? false,
        strict: j['strict'] as bool? ?? false,
        challenge: AlarmChallenge.values.asNameMap()[j['challenge']] ?? AlarmChallenge.workout,
        level: ChallengeLevel.values.asNameMap()[j['level']] ?? ChallengeLevel.medium,
        sound: AlarmSound.values.asNameMap()[j['sound']] ?? AlarmSound.sunrise,
        volume: (j['volume'] as num?)?.toDouble() ?? 0.9,
        fadeIn: j['fade'] as bool? ?? true,
        vibrate: j['vibrate'] as bool? ?? true,
      );
    } catch (_) {
      return null;
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

  /// Snoozed rings use their own id so a sync can't overwrite them.
  static int snoozeIdFor(int alarmId) => 10000 + alarmId;
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
    assetAudioPath: info.sound.assetPath,
    loopAudio: true,
    vibrate: info.vibrate,
    warningNotificationOnKill: Platform.isIOS,
    androidFullScreenIntent: true,
    androidStopAlarmOnTermination: false,
    // Two alarms set for the same minute must both ring.
    allowSameSecondScheduling: true,
    payload: info.toPayload(),
    // Strict mode: full volume from the first second, and the volume keys
    // can't turn it down (the plugin resets any change).
    volumeSettings: info.strict
        ? const VolumeSettings.fixed(volume: 1, volumeEnforced: true)
        : info.fadeIn
        ? VolumeSettings.fade(volume: info.volume, fadeDuration: const Duration(seconds: 20), volumeEnforced: true)
        : VolumeSettings.fixed(volume: info.volume, volumeEnforced: true),
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
          info: RingInfo.forAlarm(a, routine.id),
          body: 'Rise and move! Finish your ${routine.name.toLowerCase()} routine to stop the alarm 💪',
        ),
      );
    }

    // Drop anything scheduled for alarms that no longer exist.
    for (final s in await Alarm.getAlarms()) {
      if (s.id <= WorkoutAlarm.maxUserId && !wanted.contains(s.id)) await Alarm.stop(s.id);
    }
  }

  /// Rings again a few seconds from now, used to resume a strict alarm that
  /// was interrupted (e.g. the phone was switched off).
  static const recoveryId = 9998;

  static Future<void> ringSoon(RingInfo info) async {
    if (!supported) return;
    await Alarm.set(
      alarmSettings: _settings(
        id: recoveryId,
        at: DateTime.now().add(const Duration(seconds: 3)),
        info: info,
        body: 'Your alarm is still on. Finish your workout to switch it off, you\'ve got this!',
      ),
    );
  }

  /// (Re)arms the idle watchdog [idleTimeout] from now.
  static Future<void> armWatchdog(RingInfo info) async {
    if (!supported) return;
    await Alarm.set(
      alarmSettings: _settings(
        id: watchdogId,
        at: DateTime.now().add(idleTimeout),
        info: info,
        body: "You stopped moving. Keep going, you're almost there! 🔥",
      ),
    );
  }

  /// Silences [info]'s ring and rings again in its snooze length, with one
  /// fewer snooze left.
  static Future<void> snooze(RingInfo info) async {
    if (!supported || info.snoozesLeft <= 0) return;
    if (info.nativeId != null) await Alarm.stop(info.nativeId!);
    await Alarm.set(
      alarmSettings: _settings(
        id: snoozeIdFor(info.alarmId),
        at: DateTime.now().add(Duration(minutes: info.snoozeMinutes)),
        info: info.copyWith(snoozesLeft: info.snoozesLeft - 1),
        body: 'Snooze is over. Let\'s go, you\'ve got this! 💪',
      ),
    );
  }

  /// Silences every ring belonging to [info]'s alarm.
  static Future<void> silence(RingInfo info) async {
    if (!supported) return;
    for (final id in {info.nativeId, info.alarmId, snoozeIdFor(info.alarmId), watchdogId, recoveryId}) {
      if (id != null && await Alarm.isRinging(id)) await Alarm.stop(id);
    }
  }

  static Future<void> stop(int id) async {
    if (!supported) return;
    await Alarm.stop(id);
  }

  static Future<bool> isRinging(int id) async => supported && await Alarm.isRinging(id);
}
