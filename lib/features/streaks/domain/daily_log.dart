import '../../profile/domain/health_targets.dart';

/// Everything tracked for one calendar day.
class DailyLog {
  const DailyLog({
    required this.date,
    this.workoutDone = false,
    this.waterMl = 0,
    this.steps = 0,
    this.mealsLogged = 0,
    this.proteinG = 0,
  });

  final DateTime date;
  final bool workoutDone;
  final int waterMl;
  final int steps;
  final int mealsLogged;
  final int proteinG;

  DailyLog copyWith({bool? workoutDone, int? waterMl, int? steps, int? mealsLogged, int? proteinG}) => DailyLog(
    date: date,
    workoutDone: workoutDone ?? this.workoutDone,
    waterMl: waterMl ?? this.waterMl,
    steps: steps ?? this.steps,
    mealsLogged: mealsLogged ?? this.mealsLogged,
    proteinG: proteinG ?? this.proteinG,
  );

  Map<String, dynamic> toJson() => {
    'workout': workoutDone,
    'water': waterMl,
    'steps': steps,
    'meals': mealsLogged,
    'protein': proteinG,
  };

  factory DailyLog.fromJson(DateTime date, Map<String, dynamic> j) => DailyLog(
    date: date,
    workoutDone: j['workout'] as bool? ?? false,
    waterMl: j['water'] as int? ?? 0,
    steps: j['steps'] as int? ?? 0,
    mealsLogged: j['meals'] as int? ?? 0,
    proteinG: j['protein'] as int? ?? 0,
  );
}

/// The five daily pillars that colour a heatmap square.
enum DailyTask { workout, water, steps, diet, protein }

class DayScore {
  const DayScore(this.completed);

  final Set<DailyTask> completed;

  static const total = 5;

  factory DayScore.of(DailyLog log, HealthTargets t) => DayScore({
    if (log.workoutDone) DailyTask.workout,
    if (log.waterMl >= t.waterMl) DailyTask.water,
    if (log.steps >= t.steps) DailyTask.steps,
    if (log.mealsLogged >= 3) DailyTask.diet,
    if (log.proteinG >= t.proteinG) DailyTask.protein,
  });

  int get count => completed.length;

  /// Heatmap level 0–4. Missing tasks make the square lighter; only a
  /// perfect 5/5 day gets the brightest colour.
  int get level => switch (count) {
    0 => 0,
    1 || 2 => 1,
    3 => 2,
    4 => 3,
    _ => 4,
  };

  /// A day keeps the streak alive when at least 3 of 5 tasks are done.
  bool get keepsStreak => count >= 3;
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Consecutive streak days ending today (or yesterday, if today is still in
/// progress and not yet qualifying).
int currentStreak(Map<DateTime, DayScore> scores, DateTime today) {
  var day = dayOnly(today);
  if (!(scores[day]?.keepsStreak ?? false)) {
    day = day.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (scores[day]?.keepsStreak ?? false) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

int longestStreak(Map<DateTime, DayScore> scores) {
  final days = scores.entries.where((e) => e.value.keepsStreak).map((e) => e.key).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}
