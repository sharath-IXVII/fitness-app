import 'package:fitalarm/features/health/domain/health.dart';
import 'package:flutter_test/flutter_test.dart';

HealthReading _bp(DateTime at, int s, int d) => HealthReading.bloodPressure(at: at, systolic: s, diastolic: d);

void main() {
  group('blood pressure categories (AHA/ACC)', () {
    test('each band', () {
      expect(rateBloodPressure(118, 76).level, RatingLevel.normal);
      expect(rateBloodPressure(124, 78).label, 'Elevated');
      expect(rateBloodPressure(132, 78).label, 'Raised (stage 1)');
      expect(rateBloodPressure(118, 84).label, 'Raised (stage 1)');
      expect(rateBloodPressure(142, 85).label, 'High (stage 2)');
      expect(rateBloodPressure(125, 92).label, 'High (stage 2)');
      expect(rateBloodPressure(88, 70).level, RatingLevel.low);
      expect(rateBloodPressure(110, 58).level, RatingLevel.low);
    });

    test('the higher of the two numbers decides', () {
      expect(rateBloodPressure(118, 91).level, RatingLevel.high);
      expect(rateBloodPressure(150, 70).level, RatingLevel.high);
    });

    test('a crisis reading tells the person to get help', () {
      final r = rateBloodPressure(185, 100);
      expect(r.level, RatingLevel.urgent);
      expect(r.needsCare, isTrue);
      expect(r.advice, contains('112'));
      expect(rateBloodPressure(150, 125).needsCare, isTrue);
      expect(rateBloodPressure(180, 120).needsCare, isFalse); // exactly 180/120 is not above it
    });
  });

  group('blood sugar (ADA)', () {
    test('fasting', () {
      expect(rateGlucose(92, GlucoseContext.fasting).level, RatingLevel.normal);
      expect(rateGlucose(100, GlucoseContext.fasting).label, 'Higher than normal');
      expect(rateGlucose(125, GlucoseContext.fasting).level, RatingLevel.watch);
      expect(rateGlucose(126, GlucoseContext.fasting).level, RatingLevel.high);
    });

    test('after a meal', () {
      expect(rateGlucose(139, GlucoseContext.afterMeal).level, RatingLevel.normal);
      expect(rateGlucose(140, GlucoseContext.afterMeal).level, RatingLevel.watch);
      expect(rateGlucose(200, GlucoseContext.afterMeal).level, RatingLevel.high);
    });

    test('low and very high are flagged whatever the context', () {
      expect(rateGlucose(65, GlucoseContext.other).level, RatingLevel.low);
      expect(rateGlucose(50, GlucoseContext.fasting).needsCare, isTrue);
      expect(rateGlucose(320, GlucoseContext.other).needsCare, isTrue);
    });
  });

  test('pulse and oxygen', () {
    expect(ratePulse(72).level, RatingLevel.normal);
    expect(ratePulse(55).level, RatingLevel.low);
    expect(ratePulse(110).level, RatingLevel.watch);
    expect(ratePulse(130).needsCare, isTrue);
    expect(rateOxygen(98).level, RatingLevel.normal);
    expect(rateOxygen(93).level, RatingLevel.watch);
    expect(rateOxygen(90).needsCare, isTrue);
  });

  group('home blood pressure average', () {
    final now = DateTime(2026, 11, 8, 20);

    test('no readings yet', () {
      final s = homeBpSummary(const [], now);
      expect(s.count, 0);
      expect(s.hasAverage, isFalse);
      expect(s.complete, isFalse);
    });

    test('a partial week still averages, but is not complete', () {
      final s = homeBpSummary([_bp(DateTime(2026, 11, 8, 8), 120, 80), _bp(DateTime(2026, 11, 8, 8, 2), 130, 84)], now);
      expect(s.avgSystolic, 125);
      expect(s.avgDiastolic, 82);
      expect(s.count, 2);
      expect(s.complete, isFalse);
    });

    test('the first day is left out once there are enough readings', () {
      final readings = <HealthReading>[
        // Day 1 (high, as first-day readings often are).
        _bp(DateTime(2026, 11, 2, 8), 150, 95),
        _bp(DateTime(2026, 11, 2, 20), 150, 95),
        // Days 2 to 7: 2 readings, morning and evening, 12 in all.
        for (var d = 3; d <= 8; d++) ...[_bp(DateTime(2026, 11, d, 8), 120, 80), _bp(DateTime(2026, 11, d, 20), 120, 80)],
      ];
      final s = homeBpSummary(readings, now);
      expect(s.count, 12);
      expect(s.complete, isTrue);
      expect(s.avgSystolic, 120);
      expect(s.rating!.label, 'Raised (stage 1)'); // 120/80: diastolic 80 is stage 1
    });

    test('readings older than a week are ignored', () {
      final s = homeBpSummary([_bp(DateTime(2026, 10, 20, 8), 170, 100), _bp(DateTime(2026, 11, 8, 8), 118, 76)], now);
      expect(s.count, 1);
      expect(s.avgSystolic, 118);
    });
  });

  test('readings survive saving and loading, and damaged ones are skipped', () {
    final r = HealthReading.single(
      kind: ReadingKind.glucose,
      at: DateTime(2026, 5, 1, 7),
      value: 96,
      context: GlucoseContext.fasting,
    );
    final back = HealthReading.fromJson(r.toJson())!;
    expect(back.value, 96);
    expect(back.context, GlucoseContext.fasting);
    expect(back.rating.level, RatingLevel.normal);
    expect(HealthReading.fromJson({'id': 'x', 'k': 'bloodPressure', 'at': 1}), isNull);
    expect(HealthReading.fromJson({'id': 'x', 'k': 'nonsense', 'at': 1}), isNull);
  });
}
