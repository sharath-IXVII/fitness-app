import 'dart:math' as math;

/// Body mass index from height and weight, and what it means. A rough guide:
/// it does not see muscle, and it is only for adults.
double bmi(double kg, double cm) => kg / ((cm / 100) * (cm / 100));

enum BmiBand { under, healthy, over, obese }

class BmiRating {
  const BmiRating(this.band, this.label, this.advice);

  /// Null when BMI is not rated (under 18).
  final BmiBand? band;
  final String label;
  final String advice;
}

/// Asian-adjusted cut-offs, as used in Indian guidance and by the WHO for
/// Asian populations: healthy 18.5 to 22.9, overweight 23 to 24.9, obese 25
/// and above. They are lower than the global 25 and 30 because health risks
/// start at a lower weight in South Asians.
const healthyBmiLow = 18.5;
const healthyBmiHigh = 22.9;

BmiRating rateBmi(double value, {required int age}) {
  if (age < 18) {
    return const BmiRating(
      null,
      'Not rated',
      'BMI ranges are for adults aged 18 and over. For teenagers a doctor compares height and weight with growth charts.',
    );
  }
  if (value < healthyBmiLow) {
    return const BmiRating(
      BmiBand.under,
      'Underweight',
      'Below the healthy range. Eating enough, with protein and strength training, helps. See a doctor if it is not by choice.',
    );
  }
  if (value <= healthyBmiHigh) {
    return const BmiRating(BmiBand.healthy, 'Healthy range', 'Your weight suits your height. Keep your habits steady.');
  }
  if (value < 25) {
    return const BmiRating(
      BmiBand.over,
      'Overweight',
      'Slightly above the healthy range for South Asians. Daily activity and fewer sugary and fried foods help.',
    );
  }
  return const BmiRating(
    BmiBand.obese,
    'Obese range',
    'Above the healthy range. Small steady changes work best. A doctor can check your waist, blood pressure and sugar.',
  );
}

/// Weights, in kg, that give a healthy BMI at this height.
({double min, double max}) healthyWeightRange(double cm) {
  final m2 = (cm / 100) * (cm / 100);
  return (min: healthyBmiLow * m2, max: healthyBmiHigh * m2);
}

/// Allowed values when typing.
const heightRangeCm = (100.0, 230.0);
const weightRangeKg = (20.0, 300.0);

/// Body fat estimated from a tape measure (the U.S. Navy method): waist and
/// neck, plus hips for women. Usually within 3 to 4 percentage points of a
/// lab scan. Returns null for impossible measurements.
double? navyBodyFat({
  required bool female,
  required double heightCm,
  required double waistCm,
  required double neckCm,
  double? hipCm,
}) {
  double log10(double v) => math.log(v) / math.ln10;
  if (female) {
    if (hipCm == null || waistCm + hipCm - neckCm <= 0) return null;
    final v = 495 / (1.29579 - 0.35004 * log10(waistCm + hipCm - neckCm) + 0.22100 * log10(heightCm)) - 450;
    return v.isFinite && v > 2 && v < 60 ? v : null;
  }
  if (waistCm - neckCm <= 0) return null;
  final v = 495 / (1.0324 - 0.19077 * log10(waistCm - neckCm) + 0.15456 * log10(heightCm)) - 450;
  return v.isFinite && v > 2 && v < 60 ? v : null;
}

/// What a body-fat percentage means (American Council on Exercise bands),
/// in plain wellness words.
String bodyFatBand(double pct, {required bool female}) {
  final b = female ? const [14, 21, 25, 32] : const [6, 14, 18, 25];
  if (pct < b[0]) return 'Very lean';
  if (pct < b[1]) return 'Athletic';
  if (pct < b[2]) return 'Fit';
  if (pct < b[3]) return 'Average';
  return 'Above average';
}

/// Waist divided by height. Under 0.5 is a healthy sign for most adults.
double waistToHeight(double waistCm, double heightCm) => waistCm / heightCm;
