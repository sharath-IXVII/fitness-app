import 'package:flutter/material.dart';

/// A user alarm that rings until the linked routine is completed.
class WorkoutAlarm {
  const WorkoutAlarm({
    required this.id,
    required this.time,
    required this.routineId,
    this.days = const {},
    this.label = 'Wake-up workout',
    this.enabled = true,
  });

  /// Also the id used with the native alarm scheduler (1..[maxUserId]).
  final int id;
  final TimeOfDay time;

  /// ISO weekdays (1 = Monday … 7 = Sunday). Empty means ring once.
  final Set<int> days;
  final String routineId;
  final String label;
  final bool enabled;

  static const maxUserId = 9000;

  bool get repeats => days.isNotEmpty;

  /// The next moment this alarm should ring, strictly after [now].
  DateTime nextOccurrence(DateTime now) {
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset, time.hour, time.minute);
      if (!day.isAfter(now)) continue;
      if (days.isEmpty || days.contains(day.weekday)) return day;
    }
    throw StateError('unreachable: every week contains each weekday');
  }

  String get daysLabel {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
    if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (days.toList()..sort()).map((d) => names[d - 1]).join(', ');
  }

  WorkoutAlarm copyWith({TimeOfDay? time, Set<int>? days, String? routineId, String? label, bool? enabled}) =>
      WorkoutAlarm(
        id: id,
        time: time ?? this.time,
        days: days ?? this.days,
        routineId: routineId ?? this.routineId,
        label: label ?? this.label,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.hour * 60 + time.minute,
    'days': days.toList()..sort(),
    'routine': routineId,
    'label': label,
    'enabled': enabled,
  };

  factory WorkoutAlarm.fromJson(Map<String, dynamic> j) {
    final m = j['time'] as int;
    return WorkoutAlarm(
      id: j['id'] as int,
      time: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      days: {for (final d in j['days'] as List) d as int},
      routineId: j['routine'] as String,
      label: j['label'] as String? ?? 'Wake-up workout',
      enabled: j['enabled'] as bool? ?? true,
    );
  }
}
