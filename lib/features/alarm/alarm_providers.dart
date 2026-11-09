import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_providers.dart';
import '../../core/storage.dart';
import '../profile/domain/user_profile.dart';
import '../workout/domain/routine.dart';
import '../workout/routine_providers.dart';
import 'alarm_scheduler.dart';
import 'domain/workout_alarm.dart';

const _key = 'alarms.v1';

class AlarmsNotifier extends Notifier<List<WorkoutAlarm>> {
  @override
  List<WorkoutAlarm> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [for (final a in jsonDecode(raw) as List) WorkoutAlarm.fromJson(a as Map<String, dynamic>)]..sort(_byTime);
    } catch (_) {
      return const [];
    }
  }

  static int _byTime(WorkoutAlarm a, WorkoutAlarm b) =>
      (a.time.hour * 60 + a.time.minute).compareTo(b.time.hour * 60 + b.time.minute);

  int get _nextId => state.fold(0, (m, a) => a.id > m ? a.id : m) % WorkoutAlarm.maxUserId + 1;

  /// A new wake-up alarm, with a workout that suits the user's age.
  WorkoutAlarm draft() {
    final p = ref.read(profileProvider);
    return WorkoutAlarm(
      id: _nextId,
      time: const TimeOfDay(hour: 6, minute: 0),
      days: const {1, 2, 3, 4, 5, 6, 7},
      routineId: p == null ? Routine.beginner.id : Routine.forProfile(p).id,
      level: p == null ? ChallengeLevel.medium : challengeLevelForAge(p.age),
    );
  }

  /// A new bedtime alarm: gentle bells, one 10-minute snooze, Sleep mode
  /// until 3:00 AM.
  WorkoutAlarm sleepDraft() => WorkoutAlarm(
    id: _nextId,
    time: const TimeOfDay(hour: 22, minute: 30),
    days: const {1, 2, 3, 4, 5, 6, 7},
    routineId: Routine.beginner.id,
    label: 'Bedtime',
    sound: AlarmSound.bells,
    volume: 0.5,
    maxSnoozes: 1,
    snoozeMinutes: 10,
    kind: AlarmKind.sleep,
  );

  Future<void> save(WorkoutAlarm alarm) async {
    final exists = state.any((a) => a.id == alarm.id);
    await _set(exists ? [for (final a in state) a.id == alarm.id ? alarm : a] : [...state, alarm]);
  }

  Future<void> delete(int id) => _set(state.where((a) => a.id != id).toList());

  Future<void> toggle(int id, bool enabled) =>
      _set([for (final a in state) a.id == id ? a.copyWith(enabled: enabled) : a]);

  /// Silences only the next ring of a repeating alarm (or undoes that).
  Future<void> skipNext(int id, {bool skip = true}) => _set([
    for (final a in state)
      a.id == id
          ? (skip
                ? a.copyWith(skipDate: DateUtils.dateOnly(a.upcomingIgnoringSkip(DateTime.now())))
                : a.copyWith(clearSkip: true))
          : a,
  ]);

  Future<void> duplicate(WorkoutAlarm alarm) => save(alarm.copyWith(id: _nextId, enabled: false, clearSkip: true));

  /// Puts a deleted alarm back (for "Undo").
  Future<void> restore(WorkoutAlarm alarm) => save(alarm);

  /// Called after an alarm has been dealt with: one-off alarms switch off,
  /// repeating ones are re-armed for their next day.
  Future<void> handled(int id) async {
    await AlarmScheduler.stop(id);
    await AlarmScheduler.stop(AlarmScheduler.snoozeIdFor(id));
    await _set([for (final a in state) a.id == id && !a.repeats ? a.copyWith(enabled: false) : a]);
  }

  /// First alarm, created from the wake-up time chosen during onboarding.
  Future<void> createDefault(UserProfile profile) async {
    if (state.isNotEmpty) return;
    await save(
      WorkoutAlarm(
        id: 1,
        time: profile.wakeTime,
        days: const {1, 2, 3, 4, 5, 6, 7},
        routineId: Routine.forProfile(profile).id,
        level: challengeLevelForAge(profile.age),
      ),
    );
  }

  Future<void> resync() => AlarmScheduler.sync(state, ref.read(routinesProvider));

  Future<void> clearAll() => _set(const []);

  Future<void> _set(List<WorkoutAlarm> alarms) async {
    state = [...alarms]..sort(_byTime);
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode([for (final a in state) a.toJson()]));
    await resync();
  }
}

final alarmsProvider = NotifierProvider<AlarmsNotifier, List<WorkoutAlarm>>(AlarmsNotifier.new);

/// The enabled alarm that rings soonest, with its ring time.
final nextAlarmProvider = Provider<(WorkoutAlarm, DateTime)?>((ref) {
  final now = DateTime.now();
  (WorkoutAlarm, DateTime)? best;
  for (final a in ref.watch(alarmsProvider).where((a) => a.enabled)) {
    final at = a.nextOccurrence(now);
    if (best == null || at.isBefore(best.$2)) best = (a, at);
  }
  return best;
});
