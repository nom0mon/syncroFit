import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/progress/utils/bmi_utils.dart';

void main() {
  group('calculateBmi', () {
    test('calculates and formats BMI from profile measurements', () {
      final result = calculateBmi(heightCm: 175, weightKg: 70);

      expect(result, isNotNull);
      expect(result!.displayValue, '22.9');
      expect(result.category, BmiCategory.healthy);
    });

    test('rejects invalid measurements', () {
      expect(calculateBmi(heightCm: 0, weightKg: 70), isNull);
      expect(calculateBmi(heightCm: 175, weightKg: 0), isNull);
      expect(calculateBmi(heightCm: -1, weightKg: 70), isNull);
      expect(
        calculateBmi(heightCm: double.infinity, weightKg: 70),
        isNull,
      );
      expect(calculateBmi(heightCm: 175, weightKg: double.nan), isNull);
    });
  });

  group('bmiCategoryFor', () {
    test('uses the documented category boundaries', () {
      expect(bmiCategoryFor(18.49), BmiCategory.underweight);
      expect(bmiCategoryFor(18.5), BmiCategory.healthy);
      expect(bmiCategoryFor(24.99), BmiCategory.healthy);
      expect(bmiCategoryFor(25), BmiCategory.overweight);
      expect(bmiCategoryFor(29.99), BmiCategory.overweight);
      expect(bmiCategoryFor(30), BmiCategory.obesity);
    });
  });
}
