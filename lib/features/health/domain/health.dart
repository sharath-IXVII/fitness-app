import 'package:flutter/material.dart';

/// Health readings the user records from real devices (a blood pressure cuff,
/// a glucometer, a pulse oximeter or a smartwatch). Fittarc does not measure
/// anything itself; it keeps the readings, sorts them by the standard ranges
/// and shows the trend.
enum ReadingKind {
  bloodPressure('Blood pressure', 'mmHg', Icons.favorite_rounded),
  glucose('Blood sugar', 'mg/dL', Icons.water_drop_rounded),
  pulse('Resting pulse', 'bpm', Icons.monitor_heart_rounded),
  oxygen('Oxygen (SpO₂)', '%', Icons.air_rounded);

  const ReadingKind(this.label, this.unit, this.icon);

  final String label;
  final String unit;
  final IconData icon;
}

/// When a blood sugar reading was taken, which changes what is normal.
enum GlucoseContext {
  fasting('Fasting'),
  afterMeal('2 h after a meal'),
  other('Other time');

  const GlucoseContext(this.label);

  final String label;
}

/// How a reading sorts: from fine to needs care now.
enum RatingLevel {
  low(Color(0xFF2F7DBE)),
  normal(Color(0xFF2E8B57)),
  watch(Color(0xFFD9A100)),
  high(Color(0xFFE0762A)),
  urgent(Color(0xFFC0392B));

  const RatingLevel(this.color);

  final Color color;
}

/// The result of sorting one reading (or an average).
class Rating {
  const Rating(this.level, this.label, this.advice);

  final RatingLevel level;
  final String label;
  final String advice;

  bool get needsCare => level == RatingLevel.urgent;
}

/// Allowed ranges when typing a value, so a slip of the finger is caught.
abstract final class Ranges {
  static const systolic = (70, 250);
  static const diastolic = (40, 150);
  static const pulse = (30, 220);
  static const glucose = (20, 600);
  static const oxygen = (70, 100);

  static bool ok(int v, (int, int) r) => v >= r.$1 && v <= r.$2;
}

/// One saved reading. Blood pressure uses [systolic] and [diastolic] (and
/// optionally [pulse]); the other kinds use [value].
class HealthReading {
  const HealthReading({
    required this.id,
    required this.kind,
    required this.at,
    this.systolic,
    this.diastolic,
    this.value,
    this.pulse,
    this.context,
  });

  factory HealthReading.bloodPressure({required DateTime at, required int systolic, required int diastolic, int? pulse}) =>
      HealthReading(
        id: '${at.microsecondsSinceEpoch}',
        kind: ReadingKind.bloodPressure,
        at: at,
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
      );

  factory HealthReading.single({
    required ReadingKind kind,
    required DateTime at,
    required int value,
    GlucoseContext? context,
  }) => HealthReading(id: '${at.microsecondsSinceEpoch}', kind: kind, at: at, value: value, context: context);

  final String id;
  final ReadingKind kind;
  final DateTime at;
  final int? systolic;
  final int? diastolic;
  final int? value;
  final int? pulse;
  final GlucoseContext? context;

  /// "128/82" or "96".
  String get display => kind == ReadingKind.bloodPressure ? '$systolic/$diastolic' : '$value';

  Rating get rating => switch (kind) {
    ReadingKind.bloodPressure => rateBloodPressure(systolic!, diastolic!),
    ReadingKind.glucose => rateGlucose(value!, context ?? GlucoseContext.other),
    ReadingKind.pulse => ratePulse(value!),
    ReadingKind.oxygen => rateOxygen(value!),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'k': kind.name,
    'at': at.millisecondsSinceEpoch,
    if (systolic != null) 's': systolic,
    if (diastolic != null) 'd': diastolic,
    if (value != null) 'v': value,
    if (pulse != null) 'p': pulse,
    if (context != null) 'c': context!.name,
  };

  static HealthReading? fromJson(Map<String, dynamic> j) {
    try {
      final kind = ReadingKind.values.asNameMap()[j['k']];
      if (kind == null) return null;
      final r = HealthReading(
        id: j['id'] as String,
        kind: kind,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        systolic: j['s'] as int?,
        diastolic: j['d'] as int?,
        value: j['v'] as int?,
        pulse: j['p'] as int?,
        context: GlucoseContext.values.asNameMap()[j['c']],
      );
      // A damaged record is skipped rather than breaking the screen.
      if (kind == ReadingKind.bloodPressure ? r.systolic == null || r.diastolic == null : r.value == null) return null;
      return r;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------- blood pressure

/// Adult ranges from the American Heart Association / ACC guideline, which
/// matches the international hypertension thresholds (140/90 is high). Either
/// number can put a reading in a higher group.
Rating rateBloodPressure(int sys, int dia) {
  if (sys > 180 || dia > 120) {
    return const Rating(
      RatingLevel.urgent,
      'Very high',
      'Sit down and rest for 5 minutes, then measure again. If it is still this high, or you have chest pain, '
          'trouble breathing, weakness, vision or speech changes, call emergency services (112 in India) now.',
    );
  }
  if (sys >= 140 || dia >= 90) {
    return const Rating(
      RatingLevel.high,
      'High (stage 2)',
      'This is in the high range. Please see a doctor soon and bring your readings.',
    );
  }
  if (sys >= 130 || dia >= 80) {
    return const Rating(
      RatingLevel.watch,
      'Raised (stage 1)',
      'Slightly high. One reading is not a diagnosis. Keep measuring for a week and talk to a doctor if it stays here.',
    );
  }
  if (sys >= 120) {
    return const Rating(RatingLevel.watch, 'Elevated', 'A little above ideal. Salt, sleep, activity and stress all matter.');
  }
  if (sys < 90 || dia < 60) {
    return const Rating(
      RatingLevel.low,
      'Low',
      'Low readings are fine if you feel well. If you feel dizzy, faint or weak, sit down and tell a doctor.',
    );
  }
  return const Rating(RatingLevel.normal, 'Normal', 'A healthy reading. Keep it up.');
}

/// What the last week of home readings add up to.
class HomeBpSummary {
  const HomeBpSummary({
    required this.count,
    required this.days,
    required this.needed,
    this.avgSystolic,
    this.avgDiastolic,
    this.rating,
  });

  /// Readings used (the first day is left out once there are enough).
  final int count;

  /// Different days those readings cover.
  final int days;
  final int needed;
  final int? avgSystolic;
  final int? avgDiastolic;
  final Rating? rating;

  bool get complete => count >= needed;
  bool get hasAverage => avgSystolic != null;
}

/// The home blood pressure method: measure morning and evening for 7 days,
/// two readings each time, and judge the average, not a single number. The
/// first day is left out because readings settle after the first day, as the
/// guidelines advise, once at least [needed] readings remain.
HomeBpSummary homeBpSummary(Iterable<HealthReading> all, DateTime now, {int needed = 12}) {
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(const Duration(days: 6));
  var readings = [
    for (final r in all)
      if (r.kind == ReadingKind.bloodPressure && !r.at.isBefore(from) && r.at.isBefore(today.add(const Duration(days: 1)))) r,
  ]..sort((a, b) => a.at.compareTo(b.at));
  if (readings.isEmpty) return HomeBpSummary(count: 0, days: 0, needed: needed);
  DateTime day(HealthReading r) => DateTime(r.at.year, r.at.month, r.at.day);
  final firstDay = day(readings.first);
  final withoutFirst = [
    for (final r in readings)
      if (day(r) != firstDay) r,
  ];
  if (withoutFirst.length >= needed) readings = withoutFirst;
  final days = {for (final r in readings) day(r)}.length;
  final sys = (readings.fold<int>(0, (a, r) => a + r.systolic!) / readings.length).round();
  final dia = (readings.fold<int>(0, (a, r) => a + r.diastolic!) / readings.length).round();
  return HomeBpSummary(
    count: readings.length,
    days: days,
    needed: needed,
    avgSystolic: sys,
    avgDiastolic: dia,
    rating: rateBloodPressure(sys, dia),
  );
}

// ------------------------------------------------------------ blood sugar

/// Ranges from the American Diabetes Association. These sort a reading; they
/// do not diagnose diabetes, which needs a lab test and a doctor.
Rating rateGlucose(int mgdl, GlucoseContext when) {
  if (mgdl < 54) {
    return const Rating(
      RatingLevel.urgent,
      'Very low',
      'Take fast sugar now (juice, glucose tablets or sugar) and recheck in 15 minutes. If you feel confused or '
          'faint, or it does not come up, get help right away.',
    );
  }
  if (mgdl < 70) {
    return const Rating(
      RatingLevel.low,
      'Low',
      'Take 15 g of fast sugar (half a glass of juice or 3 glucose tablets) and recheck in 15 minutes.',
    );
  }
  if (mgdl >= 300) {
    return const Rating(
      RatingLevel.urgent,
      'Very high',
      'This is very high. Drink water, check again, and call your doctor today. Seek emergency care if you feel '
          'sick, are vomiting, or are very drowsy.',
    );
  }
  switch (when) {
    case GlucoseContext.fasting:
      if (mgdl < 100) return const Rating(RatingLevel.normal, 'Normal', 'A healthy fasting reading.');
      if (mgdl < 126) {
        return const Rating(
          RatingLevel.watch,
          'Higher than normal',
          'In the range doctors call prediabetes. One reading is not a diagnosis. Ask a doctor for a lab test.',
        );
      }
      return const Rating(
        RatingLevel.high,
        'High',
        'In the diabetes range for a fasting reading. Please see a doctor for a lab test.',
      );
    case GlucoseContext.afterMeal:
      if (mgdl < 140) return const Rating(RatingLevel.normal, 'Normal', 'A healthy reading two hours after eating.');
      if (mgdl < 200) {
        return const Rating(
          RatingLevel.watch,
          'Higher than normal',
          'A little high after a meal. Walking after meals helps. Mention it to a doctor if it repeats.',
        );
      }
      return const Rating(RatingLevel.high, 'High', 'High two hours after eating. Please see a doctor.');
    case GlucoseContext.other:
      if (mgdl < 140) return const Rating(RatingLevel.normal, 'Normal', 'Within the usual range.');
      if (mgdl < 200) return const Rating(RatingLevel.watch, 'Higher than normal', 'A little high. Note when you last ate.');
      return const Rating(RatingLevel.high, 'High', 'High. Please see a doctor, especially if you feel thirsty or tired.');
  }
}

// ------------------------------------------------------ pulse and oxygen

/// Resting pulse for an adult sitting quietly.
Rating ratePulse(int bpm) {
  if (bpm > 120) {
    return const Rating(
      RatingLevel.urgent,
      'Very fast at rest',
      'Rest and measure again. If it stays this fast, or you feel chest pain, faintness or breathlessness, '
          'get medical help.',
    );
  }
  if (bpm > 100) {
    return const Rating(RatingLevel.watch, 'Fast', 'Above the usual resting range. Caffeine, stress or fever can do this.');
  }
  if (bpm >= 60) return const Rating(RatingLevel.normal, 'Normal', 'Within the usual resting range of 60 to 100.');
  if (bpm >= 40) {
    return const Rating(
      RatingLevel.low,
      'Slow',
      'Common in fit people. If you also feel dizzy or faint, tell a doctor.',
    );
  }
  return const Rating(RatingLevel.urgent, 'Very slow', 'This is very slow. If you feel unwell, get medical help.');
}

/// Oxygen saturation from a pulse oximeter, at rest.
Rating rateOxygen(int percent) {
  if (percent >= 95) return const Rating(RatingLevel.normal, 'Normal', 'A healthy oxygen level.');
  if (percent >= 91) {
    return const Rating(
      RatingLevel.watch,
      'Lower than usual',
      'Rest, sit up straight, warm your hands and measure again. If it stays here, tell a doctor.',
    );
  }
  return const Rating(
    RatingLevel.urgent,
    'Low',
    '90% or lower is low. If it stays low after measuring again, or you are short of breath, seek medical help now.',
  );
}
