import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  WorkoutAlarm draft() => WorkoutAlarm(
    id: _nextId,
    time: const TimeOfDay(hour: 6, minute: 0),
    days: const {1, 2, 3, 4, 5, 6, 7},
    routineId: Routine.beginner.id,
  );

  Future<void> save(WorkoutAlarm alarm) async {
    final exists = state.any((a) => a.id == alarm.id);
    await _set(exists ? [for (final a in state) a.id == alarm.id ? alarm : a] : [...state, alarm]);
  }

  Future<void> delete(int id) => _set(state.where((a) => a.id != id).toList());

  Future<void> toggle(int id, bool enabled) =>
      _set([for (final a in state) a.id == id ? a.copyWith(enabled: enabled) : a]);

  /// Called after an alarm has been dealt with: one-off alarms switch off,
  /// repeating ones are re-armed for their next day.
  Future<void> handled(int id) async {
    await AlarmScheduler.stop(id);
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
        routineId: Routine.forLevel(profile.level).id,
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
