import '../../profile/domain/health_targets.dart';
import '../../streaks/domain/daily_log.dart';

/// One line of the day: how much was done of a goal.
class ReportLine {
  const ReportLine(this.label, this.done, this.goal, this.unit);

  final String label;
  final num done;
  final num goal;
  final String unit;

  double get part => goal <= 0 ? 0 : (done / goal).clamp(0, 1).toDouble();
}

/// The day in numbers, with a score out of 100: each of the five daily
/// goals (workout, water, steps, three meals, protein) is worth 20, with
/// part marks for part of a goal.
class DailyReport {
  const DailyReport({
    required this.day,
    required this.workoutDone,
    required this.lines,
    required this.kcalEaten,
    required this.kcalTarget,
    required this.snaps,
    required this.clubKm,
    required this.streak,
  });

  factory DailyReport.of(
    DailyLog log,
    HealthTargets t, {
    required double kcalEaten,
    int snaps = 0,
    double clubKm = 0,
    int streak = 0,
  }) => DailyReport(
    day: log.date,
    workoutDone: log.workoutDone,
    lines: [
      ReportLine('Steps', log.steps, t.steps, ''),
      ReportLine('Water', log.waterMl, t.waterMl, 'ml'),
      ReportLine('Meals logged', log.mealsLogged, 3, ''),
      ReportLine('Protein', log.proteinG, t.proteinG, 'g'),
    ],
    kcalEaten: kcalEaten,
    kcalTarget: t.calories.toDouble(),
    snaps: snaps,
    clubKm: clubKm,
    streak: streak,
  );

  final DateTime day;
  final bool workoutDone;
  final List<ReportLine> lines;
  final double kcalEaten;
  final double kcalTarget;
  final int snaps;
  final double clubKm;
  final int streak;

  int get score => ((workoutDone ? 20 : 0) + lines.fold(0.0, (a, l) => a + l.part * 20)).round();

  /// A short line about the day.
  String get verdict => switch (score) {
    >= 90 => 'Champion day! Everything done. 🏆',
    >= 70 => 'Strong day. Just a little left.',
    >= 40 => 'Good effort. Tomorrow, finish the rest.',
    _ => 'A quiet day. Tomorrow is a fresh start.',
  };

  /// What to do tomorrow: the goal furthest from done.
  String? get tip {
    if (!workoutDone) return 'Tomorrow: start with your workout. Even 10 minutes counts.';
    final worst = [...lines]..sort((a, b) => a.part.compareTo(b.part));
    final l = worst.first;
    if (l.part >= 1) return null;
    return switch (l.label) {
      'Steps' => 'Tomorrow: add a 15-minute walk after a meal.',
      'Water' => 'Tomorrow: keep a bottle near you and sip every hour.',
      'Meals logged' => 'Tomorrow: snap each meal so FittArc can count it.',
      _ => 'Tomorrow: add dal, eggs, paneer or sprouts for more protein.',
    };
  }
}
