import 'package:flutter/material.dart';

import 'challenge.dart';

export 'challenge.dart';

enum AlarmSound {
  sunrise('Morning chime', 'sunrise'),
  bells('Gentle bells', 'bells'),
  pulse('Energy pulse', 'pulse'),
  classic('Classic beep', 'classic');

  const AlarmSound(this.label, this.file);

  final String label;
  final String file;

  String get assetPath => 'assets/sounds/$file.wav';
}

/// The next time after [start] that the clock reads [minutes] after midnight.
DateTime clockTimeAfter(DateTime start, int minutes) {
  var end = DateTime(start.year, start.month, start.day, minutes ~/ 60, minutes % 60);
  if (!end.isAfter(start)) end = DateTime(start.year, start.month, start.day + 1, minutes ~/ 60, minutes % 60);
  return end;
}

/// A wake-up alarm rings until its workout or game is done. A bedtime alarm
/// is a gentle reminder to sleep that can start Sleep mode.
enum AlarmKind { wake, sleep }

/// A user alarm that rings until the linked routine is completed (wake-up),
/// or reminds you to sleep (bedtime).
class WorkoutAlarm {
  const WorkoutAlarm({
    required this.id,
    required this.time,
    required this.routineId,
    this.days = const {},
    this.label = 'Wake-up workout',
    this.enabled = true,
    this.sound = AlarmSound.sunrise,
    this.volume = 1.0,
    this.fadeIn = true,
    this.vibrate = true,
    this.maxSnoozes = 1,
    this.snoozeMinutes = 5,
    this.hardMode = false,
    this.strict = false,
    this.challenge = AlarmChallenge.workout,
    this.level = ChallengeLevel.medium,
    this.skipDate,
    this.kind = AlarmKind.wake,
    this.sleepEnd = defaultSleepEnd,
  });

  /// Also the id used with the native alarm scheduler (1..[maxUserId]).
  final int id;
  final TimeOfDay time;

  /// ISO weekdays (1 = Monday … 7 = Sunday). Empty means ring once.
  final Set<int> days;
  final String routineId;
  final String label;
  final bool enabled;

  final AlarmSound sound;
  final double volume;

  /// Start quiet and rise to [volume] over the first seconds.
  final bool fadeIn;
  final bool vibrate;
  final int maxSnoozes;
  final int snoozeMinutes;

  /// No snooze and no emergency stop: the workout is the only way out.
  final bool hardMode;

  /// Strict mode: everything in [hardMode], plus volume locked at maximum
  /// and the phone kept on the alarm until the challenge is done.
  final bool strict;

  /// How the alarm is turned off, and how hard the brain games are.
  final AlarmChallenge challenge;
  final ChallengeLevel level;

  /// A single day on which a repeating alarm stays silent.
  final DateTime? skipDate;

  /// Wake-up or bedtime.
  final AlarmKind kind;

  /// Bedtime alarms: when Sleep mode ends, in minutes after midnight
  /// (3:00 AM by default). For a bedtime alarm, [strict] means "block other
  /// apps" during Sleep mode, not "no escape from the ring".
  final int sleepEnd;

  static const defaultSleepEnd = 3 * 60;
  static const maxUserId = 9000;

  bool get isSleep => kind == AlarmKind.sleep;

  /// The moment Sleep mode ends for a bedtime that begins at [start]: the
  /// next [sleepEnd] clock time after it.
  DateTime sleepEndAfter(DateTime start) => clockTimeAfter(start, sleepEnd);

  bool get repeats => days.isNotEmpty;
  bool get noEscape => !isSleep && (hardMode || strict);
  int get allowedSnoozes => noEscape ? 0 : maxSnoozes;

  /// The next moment this alarm should ring, strictly after [now].
  DateTime nextOccurrence(DateTime now) {
    for (var offset = 0; offset <= 14; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset, time.hour, time.minute);
      if (!day.isAfter(now)) continue;
      if (days.isNotEmpty && !days.contains(day.weekday)) continue;
      if (skipDate != null && DateUtils.isSameDay(day, skipDate)) continue;
      return day;
    }
    throw StateError('unreachable: every fortnight contains each weekday twice');
  }

  /// The occurrence that "skip next" would silence.
  DateTime upcomingIgnoringSkip(DateTime now) => copyWith(clearSkip: true).nextOccurrence(now);

  bool isSkipping(DateTime now) => skipDate != null && !skipDate!.isBefore(DateUtils.dateOnly(now));

  String get daysLabel {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
    if (days.length == 2 && days.containsAll({6, 7})) return 'Weekends';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (days.toList()..sort()).map((d) => names[d - 1]).join(', ');
  }

  WorkoutAlarm copyWith({
    int? id,
    TimeOfDay? time,
    Set<int>? days,
    String? routineId,
    String? label,
    bool? enabled,
    AlarmSound? sound,
    double? volume,
    bool? fadeIn,
    bool? vibrate,
    int? maxSnoozes,
    int? snoozeMinutes,
    bool? hardMode,
    bool? strict,
    AlarmChallenge? challenge,
    ChallengeLevel? level,
    DateTime? skipDate,
    AlarmKind? kind,
    int? sleepEnd,
    bool clearSkip = false,
  }) => WorkoutAlarm(
    id: id ?? this.id,
    time: time ?? this.time,
    days: days ?? this.days,
    routineId: routineId ?? this.routineId,
    label: label ?? this.label,
    enabled: enabled ?? this.enabled,
    sound: sound ?? this.sound,
    volume: volume ?? this.volume,
    fadeIn: fadeIn ?? this.fadeIn,
    vibrate: vibrate ?? this.vibrate,
    maxSnoozes: maxSnoozes ?? this.maxSnoozes,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    hardMode: hardMode ?? this.hardMode,
    strict: strict ?? this.strict,
    challenge: challenge ?? this.challenge,
    level: level ?? this.level,
    skipDate: clearSkip ? null : (skipDate ?? this.skipDate),
    kind: kind ?? this.kind,
    sleepEnd: sleepEnd ?? this.sleepEnd,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.hour * 60 + time.minute,
    'days': days.toList()..sort(),
    'routine': routineId,
    'label': label,
    'enabled': enabled,
    'sound': sound.name,
    'volume': volume,
    'fadeIn': fadeIn,
    'vibrate': vibrate,
    'maxSnoozes': maxSnoozes,
    'snoozeMinutes': snoozeMinutes,
    'hardMode': hardMode,
    'strict': strict,
    'challenge': challenge.name,
    'level': level.name,
    if (skipDate != null) 'skip': skipDate!.toIso8601String(),
    'kind': kind.name,
    'sleepEnd': sleepEnd,
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
      sound: AlarmSound.values.asNameMap()[j['sound']] ?? AlarmSound.sunrise,
      volume: (j['volume'] as num?)?.toDouble() ?? 0.9,
      fadeIn: j['fadeIn'] as bool? ?? true,
      vibrate: j['vibrate'] as bool? ?? true,
      maxSnoozes: j['maxSnoozes'] as int? ?? 1,
      snoozeMinutes: j['snoozeMinutes'] as int? ?? 5,
      hardMode: j['hardMode'] as bool? ?? false,
      strict: j['strict'] as bool? ?? false,
      challenge: AlarmChallenge.values.asNameMap()[j['challenge']] ?? AlarmChallenge.workout,
      level: ChallengeLevel.values.asNameMap()[j['level']] ?? ChallengeLevel.medium,
      skipDate: j['skip'] == null ? null : DateTime.parse(j['skip'] as String),
      kind: AlarmKind.values.asNameMap()[j['kind']] ?? AlarmKind.wake,
      sleepEnd: j['sleepEnd'] as int? ?? defaultSleepEnd,
    );
  }
}
