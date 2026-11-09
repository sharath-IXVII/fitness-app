import 'package:flutter/material.dart';

/// Readings FittArc keeps for the user. Only the resting pulse is kept, from
/// the camera heart-rate estimate. FittArc is a wellness app: it does not log
/// or sort medical values such as blood pressure, blood sugar or oxygen.
enum ReadingKind {
  pulse('Resting pulse', 'bpm', Icons.monitor_heart_rounded);

  const ReadingKind(this.label, this.unit, this.icon);

  final String label;
  final String unit;
  final IconData icon;
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

/// The result of sorting one reading.
class Rating {
  const Rating(this.level, this.label, this.advice);

  final RatingLevel level;
  final String label;
  final String advice;

  bool get needsCare => level == RatingLevel.urgent;
}

/// One saved reading.
class HealthReading {
  const HealthReading({required this.id, required this.kind, required this.at, required this.value});

  factory HealthReading.single({required ReadingKind kind, required DateTime at, required int value}) =>
      HealthReading(id: '${at.microsecondsSinceEpoch}', kind: kind, at: at, value: value);

  final String id;
  final ReadingKind kind;
  final DateTime at;
  final int value;

  String get display => '$value';

  Rating get rating => ratePulse(value);

  Map<String, dynamic> toJson() => {'id': id, 'k': kind.name, 'at': at.millisecondsSinceEpoch, 'v': value};

  /// Null for a damaged record or a kind the app no longer keeps (older
  /// versions also stored blood pressure, sugar and oxygen).
  static HealthReading? fromJson(Map<String, dynamic> j) {
    try {
      final kind = ReadingKind.values.asNameMap()[j['k']];
      final value = j['v'] as int?;
      if (kind == null || value == null) return null;
      return HealthReading(
        id: j['id'] as String,
        kind: kind,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        value: value,
      );
    } catch (_) {
      return null;
    }
  }
}

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
    return const Rating(
      RatingLevel.watch,
      'Fast',
      'Above the usual resting range. Caffeine, stress or fever can do this.',
    );
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
