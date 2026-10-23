import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'sheet_frame.dart';

enum Nutrient {
  calories(
    'Calories',
    Icons.local_fire_department_outlined,
    'Energy',
    'A calorie is a unit of energy. Your body burns calories to breathe, think and move. Eat fewer than you '
        'burn and you lose weight; eat more and you gain. Your target is worked out from your height, weight, '
        'age and activity.',
    ['About 7,700 kcal ≈ 1 kg of body weight.', 'A 500 kcal daily gap ≈ 0.5 kg a week.'],
  ),
  protein(
    'Protein',
    Icons.egg_alt_outlined,
    'Builds and repairs',
    'Protein builds and repairs muscle, skin and hair, and keeps you full for longer. It matters most when '
        'you\'re losing fat (to keep muscle) or building muscle. 1 g gives 4 kcal.',
    ['Veg: paneer, curd, dal, chana, soya, tofu, milk.', 'Non-veg: eggs, chicken, fish.', 'Spread it across meals.'],
  ),
  carbs(
    'Carbs',
    Icons.grain_outlined,
    'Your main fuel',
    'Carbohydrates are your body\'s main fuel, especially for the brain and for workouts. Whole grains, fruit '
        'and pulses release energy slowly; sugar and refined flour spike it. 1 g gives 4 kcal.',
    ['Better: oats, brown rice, millets, roti, fruit.', 'Limit: sugar, sweets, soft drinks, maida.'],
  ),
  fat(
    'Fat',
    Icons.water_drop_outlined,
    'Hormones and vitamins',
    'Fat is needed for hormones and to absorb vitamins A, D, E and K. It\'s energy-dense: 1 g gives 9 kcal, '
        'so small amounts add up quickly. About a quarter of your calories from fat is a healthy range.',
    ['Good: nuts, seeds, olive/mustard oil, fish.', 'Watch: fried food, ghee and butter in large amounts.'],
  ),
  fiber(
    'Fiber',
    Icons.eco_outlined,
    'Digestion and fullness',
    'Fiber is the part of plants you can\'t digest. It keeps digestion regular, steadies blood sugar and helps '
        'you feel full on fewer calories. Aim for about 14 g per 1,000 kcal you eat.',
    ['Vegetables, fruit with skin, dal, chana, oats, whole wheat.', 'Drink more water as you eat more fiber.'],
  );

  const Nutrient(this.label, this.icon, this.tagline, this.body, this.tips);

  final String label;
  final IconData icon;
  final String tagline;
  final String body;
  final List<String> tips;
}

void showNutrientExplainer(BuildContext context, Nutrient n) {
  final text = Theme.of(context).textTheme;
  SheetFrame.show<void>(
    context,
    SheetFrame(
      title: 'What is ${n.label.toLowerCase()}?',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
                  child: Icon(n.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(n.tagline, style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            Text(n.body, style: text.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 14),
            for (final tip in n.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
