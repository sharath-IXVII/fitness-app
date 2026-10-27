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
