/// Informational BMI classifications used by the Progress module.
enum BmiCategory {
  underweight('Underweight'),
  healthy('Healthy'),
  overweight('Overweight'),
  obesity('Obesity');

  const BmiCategory(this.label);

  final String label;
}

/// A valid BMI value and its informational classification.
class BmiResult {
  const BmiResult({required this.value, required this.category});

  final double value;
  final BmiCategory category;

  String get displayValue => value.toStringAsFixed(1);
}

/// Calculates BMI from metric profile measurements.
///
/// Returns `null` rather than exposing NaN/infinity for missing or invalid
/// measurements. The value itself remains unrounded so category boundaries are
/// evaluated accurately; UI display is rounded to one decimal place.
BmiResult? calculateBmi({
  required double heightCm,
  required double weightKg,
}) {
  if (!heightCm.isFinite ||
      !weightKg.isFinite ||
      heightCm <= 0 ||
      weightKg <= 0) {
    return null;
  }

  final heightMeters = heightCm / 100;
  final value = weightKg / (heightMeters * heightMeters);
  if (!value.isFinite) return null;

  return BmiResult(value: value, category: bmiCategoryFor(value));
}

/// Classifies a valid BMI value using standard adult category boundaries.
BmiCategory bmiCategoryFor(double bmi) {
  if (bmi < 18.5) return BmiCategory.underweight;
  if (bmi < 25) return BmiCategory.healthy;
  if (bmi < 30) return BmiCategory.overweight;
  return BmiCategory.obesity;
}
