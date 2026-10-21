import 'dart:math' as math;

/// About 7,700 kcal per kg of body fat.
const kcalPerKg = 7700.0;

enum GoalPace { maintain, realistic, ambitious, tooFast }

/// "Reach [targetKg] by [deadline]" — turned into a weekly pace and a daily
/// calorie adjustment, capped at safe limits.
class WeightGoal {
  const WeightGoal({required this.startKg, required this.targetKg, required this.deadline, required this.createdAt});

  final double startKg;
  final double targetKg;
  final DateTime deadline;
  final DateTime createdAt;

  /// Safe limits: lose up to 1 kg a week, gain up to 0.5 kg a week.
  static const maxLossPerWeek = 1.0;
  static const maxGainPerWeek = 0.5;

  double weeksLeft(DateTime now) => math.max(1, deadline.difference(now).inDays) / 7;

  /// Weekly change needed from [currentKg] (negative = loss).
  double neededPerWeek(double currentKg, DateTime now) => (targetKg - currentKg) / weeksLeft(now);

  GoalPace pace(double currentKg, DateTime now) {
    final w = neededPerWeek(currentKg, now);
    if (w.abs() < 0.05) return GoalPace.maintain;
    final limit = w < 0 ? maxLossPerWeek : maxGainPerWeek;
    if (w.abs() > limit) return GoalPace.tooFast;
    if (w.abs() > limit * 0.7) return GoalPace.ambitious;
    return GoalPace.realistic;
  }

  /// Calories to add (positive) or remove (negative) per day, capped at the
  /// safe weekly limit.
  int dailyAdjustment(double currentKg, DateTime now) {
    final w = neededPerWeek(currentKg, now).clamp(-maxLossPerWeek, maxGainPerWeek);
    return (w * kcalPerKg / 7).round();
  }

  /// The date the goal is reached at the capped safe pace.
  DateTime safeEta(double currentKg, DateTime now) {
    final diff = targetKg - currentKg;
    final perWeek = diff < 0 ? maxLossPerWeek : maxGainPerWeek;
    return now.add(Duration(days: (diff.abs() / perWeek * 7).ceil()));
  }

  double progress(double currentKg) {
    final total = targetKg - startKg;
    if (total.abs() < 0.01) return 1;
    return ((currentKg - startKg) / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'start': startKg,
    'target': targetKg,
    'deadline': deadline.toIso8601String(),
    'created': createdAt.toIso8601String(),
  };

  factory WeightGoal.fromJson(Map<String, dynamic> j) => WeightGoal(
    startKg: (j['start'] as num).toDouble(),
    targetKg: (j['target'] as num).toDouble(),
    deadline: DateTime.parse(j['deadline'] as String),
    createdAt: DateTime.parse(j['created'] as String),
  );
}
