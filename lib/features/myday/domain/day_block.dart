import 'package:flutter/material.dart';

enum BlockKind {
  wake('Wake up', Icons.wb_twilight_rounded),
  workout('Workout', Icons.fitness_center_rounded),
  walk('Walk', Icons.directions_walk_rounded),
  breakfast('Breakfast', Icons.free_breakfast_rounded),
  lunch('Lunch', Icons.lunch_dining_rounded),
  snack('Snack', Icons.cookie_outlined),
  dinner('Dinner', Icons.dinner_dining_rounded),
  water('Drink water', Icons.water_drop_outlined),
  work('Work', Icons.work_outline_rounded),
  study('Study', Icons.menu_book_rounded),
  rest('Break', Icons.self_improvement_rounded),
  sleep('Sleep', Icons.bedtime_outlined),
  custom('Custom', Icons.bolt_rounded);

  const BlockKind(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isMeal => this == breakfast || this == lunch || this == snack || this == dinner;
}

/// One item in the user's daily routine.
class DayBlock {
  const DayBlock({
    required this.id,
    required this.kind,
    required this.time,
    String? title,
    this.minutes = 0,
    this.days = const {1, 2, 3, 4, 5, 6, 7},
    this.remind = true,
    this.leadMinutes = 0,
  }) : title = title ?? '';

  final int id;
  final BlockKind kind;
  final TimeOfDay time;

  /// Empty means "use the kind's label".
  final String title;

  /// Duration in minutes; 0 for an instant item like "Drink water".
  final int minutes;

  /// ISO weekdays this block happens on.
  final Set<int> days;
  final bool remind;

  /// Remind this many minutes before [time].
  final int leadMinutes;

  String get name => title.trim().isEmpty ? kind.label : title.trim();
  int get startMinute => time.hour * 60 + time.minute;
  int get endMinute => startMinute + minutes;

  /// When the reminder fires, as minutes after midnight (may wrap to the
  /// previous day, handled by the scheduler).
  int get remindMinute => startMinute - leadMinutes;

  bool occursOn(int weekday) => days.contains(weekday);

  DayBlock copyWith({
    int? id,
    BlockKind? kind,
    TimeOfDay? time,
    String? title,
    int? minutes,
    Set<int>? days,
    bool? remind,
    int? leadMinutes,
  }) => DayBlock(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    time: time ?? this.time,
    title: title ?? this.title,
    minutes: minutes ?? this.minutes,
    days: days ?? this.days,
    remind: remind ?? this.remind,
    leadMinutes: leadMinutes ?? this.leadMinutes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'time': startMinute,
    'title': title,
    'minutes': minutes,
    'days': days.toList()..sort(),
    'remind': remind,
    'lead': leadMinutes,
  };

  factory DayBlock.fromJson(Map<String, dynamic> j) {
    final m = j['time'] as int;
    return DayBlock(
      id: j['id'] as int,
      kind: BlockKind.values.asNameMap()[j['kind']] ?? BlockKind.custom,
      time: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      title: j['title'] as String? ?? '',
      minutes: j['minutes'] as int? ?? 0,
      days: {for (final d in j['days'] as List) d as int},
      remind: j['remind'] as bool? ?? true,
      leadMinutes: j['lead'] as int? ?? 0,
    );
  }
}

/// Blocks for [weekday], in time order.
List<DayBlock> blocksFor(List<DayBlock> all, int weekday) =>
    all.where((b) => b.occursOn(weekday)).toList()..sort((a, b) => a.startMinute.compareTo(b.startMinute));

/// The block happening at [minute], or the next one to start.
DayBlock? currentOrNext(List<DayBlock> today, int minute) {
  for (final b in today) {
    if (minute < b.startMinute || (b.minutes > 0 && minute < b.endMinute)) return b;
  }
  return null;
}

const _weekdays = {1, 2, 3, 4, 5};
const _weekend = {6, 7};

/// Starter routines the user can pick and then edit.
enum RoutineTemplate {
  student('Student', 'Classes, study blocks and an evening workout', Icons.school_outlined),
  office('Office', '9-to-6 with a lunchtime walk and evening workout', Icons.work_outline_rounded),
  earlyRiser('Early riser', 'Up at 5, workout first, early nights', Icons.wb_twilight_rounded),
  gymBeginner('Gym beginner', 'Simple day built around one gym session', Icons.fitness_center_rounded);

  const RoutineTemplate(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  List<DayBlock> build(TimeOfDay wake, TimeOfDay sleep) {
    var id = 0;
    DayBlock b(BlockKind k, int h, int m, {String? title, int minutes = 0, Set<int>? days, int lead = 0}) => DayBlock(
      id: ++id,
      kind: k,
      time: TimeOfDay(hour: h, minute: m),
      title: title,
      minutes: minutes,
      days: days ?? const {1, 2, 3, 4, 5, 6, 7},
      leadMinutes: lead,
    );
    final w = wake, s = sleep;
    DayBlock wakeB() => b(BlockKind.wake, w.hour, w.minute);
    DayBlock sleepB() => b(BlockKind.sleep, s.hour, s.minute, lead: 15);
    return switch (this) {
      student => [
        wakeB(),
        b(BlockKind.breakfast, w.hour + 1, 0, minutes: 20),
        b(BlockKind.study, 9, 0, title: 'Classes', minutes: 240, days: _weekdays),
        b(BlockKind.water, 11, 0),
        b(BlockKind.lunch, 13, 15, minutes: 30),
        b(BlockKind.study, 15, 0, title: 'Self-study', minutes: 120),
        b(BlockKind.snack, 17, 0),
        b(BlockKind.workout, 18, 0, minutes: 45, lead: 10),
        b(BlockKind.dinner, 20, 0, minutes: 30),
        sleepB(),
      ],
      office => [
        wakeB(),
        b(BlockKind.breakfast, 8, 0, minutes: 20),
        b(BlockKind.work, 9, 30, minutes: 210, days: _weekdays, lead: 15),
        b(BlockKind.water, 11, 0, days: _weekdays),
        b(BlockKind.lunch, 13, 0, minutes: 30),
        b(BlockKind.walk, 13, 30, title: 'Post-lunch walk', minutes: 15),
        b(BlockKind.work, 14, 0, minutes: 240, days: _weekdays),
        b(BlockKind.snack, 16, 30),
        b(BlockKind.workout, 19, 0, minutes: 45, lead: 10),
        b(BlockKind.dinner, 20, 30, minutes: 30),
        sleepB(),
      ],
      earlyRiser => [
        b(BlockKind.wake, 5, 0),
        b(BlockKind.workout, 5, 30, minutes: 45),
        b(BlockKind.breakfast, 7, 0, minutes: 20),
        b(BlockKind.work, 8, 30, minutes: 240, days: _weekdays),
        b(BlockKind.lunch, 12, 30, minutes: 30),
        b(BlockKind.snack, 16, 0),
        b(BlockKind.walk, 18, 0, title: 'Evening walk', minutes: 30),
        b(BlockKind.dinner, 19, 0, minutes: 30),
        b(BlockKind.sleep, 21, 30, lead: 15),
      ],
      gymBeginner => [
        wakeB(),
        b(BlockKind.breakfast, w.hour + 1, 0, title: 'High-protein breakfast', minutes: 20),
        b(BlockKind.snack, 11, 0),
        b(BlockKind.lunch, 13, 30, minutes: 30),
        b(BlockKind.snack, 16, 30, title: 'Pre-workout snack'),
        b(BlockKind.workout, 17, 30, title: 'Gym', minutes: 60, days: {1, 2, 3, 4, 5, 6}, lead: 15),
        b(BlockKind.walk, 10, 0, title: 'Rest-day walk', minutes: 30, days: {7}),
        b(BlockKind.dinner, 20, 0, minutes: 30),
        sleepB(),
      ],
    };
  }
}

/// Default for weekends in the office template etc. is handled by [DayBlock.days].
const weekdaySets = (all: {1, 2, 3, 4, 5, 6, 7}, weekdays: _weekdays, weekend: _weekend);
