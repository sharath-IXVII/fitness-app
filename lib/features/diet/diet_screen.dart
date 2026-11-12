import 'dart:math' as math;

import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/beta_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../profile/domain/user_profile.dart';
import '../profile/profile_providers.dart';
import 'diet_providers.dart';
import '../snaps/widgets/today_snaps.dart';
import 'domain/food.dart';
import 'domain/meal_log.dart';
import 'domain/weight_goal.dart';
import 'widgets/food_search_sheet.dart';
import 'widgets/goal_sheets.dart';
import 'widgets/meal_photo.dart';
import 'widgets/nutrient_explainer.dart';
import 'widgets/sheet_frame.dart';

/// Phase 5: calorie and macro tracking, a daily meal plan for the user's
/// diet, a weight goal with a deadline, and plain-language explainers.
class DietScreen extends ConsumerWidget {
  const DietScreen({super.key});

  static const dietLabels = {
    DietType.veg: 'Vegetarian',
    DietType.nonVeg: 'Non-vegetarian',
    DietType.eggetarian: 'Eggetarian',
    DietType.vegan: 'Vegan',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider);
    final targets = ref.watch(dietTargetsProvider);
    if (profile == null || targets == null) return const SizedBox.shrink();
    final entries = ref.watch(mealLogProvider);
    final totals = ref.watch(mealTotalsProvider);

    // Food is added by snapping the plate; the result can be edited there.
    void add(MealType m) => context.push(Routes.scan, extra: m);

    final sections = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tr('Diet'), style: text.headlineMedium),
                    const SizedBox(width: 10),
                    const BetaTag(visible: true),
                  ],
                ),
                Text(dietLabels[profile.diet]!, style: text.bodyMedium),
              ],
            ),
          ),
          Pressable(
            onTap: () => context.push(Routes.scan, extra: _suggestedMeal()),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.photo_camera_outlined, color: AppColors.primary, semanticLabel: 'Scan food'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const BetaNote(),
      const SizedBox(height: 14),
      _CaloriesCard(totals: totals, targets: targets),
      const TodaySnaps(),
      const SizedBox(height: 14),
      const _GoalCard(),
      const SizedBox(height: 26),
      for (final m in MealType.values) ...[
        _MealSection(
          meal: m,
          entries: [...entries.where((e) => e.meal == m)],
          budget: (targets.calories * m.share).round(),
          onAdd: () => add(m),
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 14),
      const _WeightCard(),
      const SizedBox(height: 26),
      Pressable(
        onTap: () => context.push(Routes.foodGuide),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(tr('Food guide: what is in 100 g of common foods'), style: text.titleSmall)),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(tr('Learn the basics'), style: text.titleMedium),
      const SizedBox(height: 10),
      const _LearnRow(),
      const SizedBox(height: 32),
    ];

    return PageBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          children: [
            for (final (i, s) in sections.indexed)
              s
                  .animate(delay: (math.min(i, 8) * 30).ms)
                  .fadeIn(duration: 300.ms)
                  .moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  static MealType _suggestedMeal() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 16) return MealType.lunch;
    if (h < 18) return MealType.snack;
    return MealType.dinner;
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.totals, required this.targets});

  final Macros totals;
  final DietTargets targets;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final eaten = totals.kcal.round();
    final left = targets.calories - eaten;
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Pressable(
                onTap: () => showNutrientExplainer(context, Nutrient.calories),
                child: ProgressRing(
                  progress: eaten / targets.calories,
                  color: left < 0 ? AppColors.danger : AppColors.primary,
                  size: 128,
                  stroke: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedNumber(left.abs(), style: text.headlineSmall),
                      Text(left < 0 ? 'kcal over' : 'kcal left', style: text.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Kv('Eaten', '$eaten kcal'),
                    const SizedBox(height: 8),
                    _Kv('Target', '${targets.calories} kcal'),
                    if (targets.adjustment != null) ...[
                      const SizedBox(height: 8),
                      _Kv(
                        'Goal pace',
                        targets.adjustment! == 0
                            ? 'maintain'
                            : '${targets.adjustment! > 0 ? '+' : '−'}${targets.adjustment!.abs()} kcal/day',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MacroBar(Nutrient.protein, totals.protein, targets.protein, AppColors.protein),
              const SizedBox(width: 10),
              _MacroBar(Nutrient.carbs, totals.carbs, targets.carbs, AppColors.accent),
              const SizedBox(width: 10),
              _MacroBar(Nutrient.fat, totals.fat, targets.fat, AppColors.gold),
              const SizedBox(width: 10),
              _MacroBar(Nutrient.fiber, totals.fiber, targets.fiber, AppColors.steps),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(k, style: text.bodyMedium)),
        Text(v, style: text.titleSmall),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar(this.nutrient, this.value, this.target, this.color);

  final Nutrient nutrient;
  final double value;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Pressable(
        onTap: () => showNutrientExplainer(context, nutrient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(nutrient.label, style: text.labelMedium, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 3),
                Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: target == 0 ? 0 : (value / target).clamp(0, 1)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  color: color,
                  backgroundColor: AppColors.surfaceHigh,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text('${value.round()}/${target}g', style: text.bodySmall?.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.entries, required this.budget, required this.onAdd});

  final MealType meal;
  final List<MealEntry> entries;
  final int budget;
  final VoidCallback onAdd;

  static const _icons = {
    MealType.breakfast: Icons.free_breakfast_outlined,
    MealType.lunch: Icons.lunch_dining_outlined,
    MealType.snack: Icons.cookie_outlined,
    MealType.dinner: Icons.dinner_dining_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kcal = totalOf(entries).kcal.round();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      glow: entries.isEmpty ? null : AppColors.primary,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
                child: Icon(_icons[meal], size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.label, style: text.titleSmall),
                    Text(entries.isEmpty ? 'About $budget kcal' : '$kcal of ~$budget kcal', style: text.bodySmall),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(tr('Snap')),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (final e in entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => SheetFrame.show<void>(context, EntryEditSheet(entry: e)),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(e.photo == null ? 50 : 0, 8, 8, 8),
                      child: Row(
                        children: [
                          if (e.photo != null) ...[
                            SizedBox(width: 38, child: MealPhoto(name: e.photo!, size: 38)),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.name, style: text.bodyLarge, overflow: TextOverflow.ellipsis),
                                Text(
                                  '${_servings(e.servings)} · ${e.macros.protein.round()} g protein',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text('${e.macros.kcal.round()} kcal', style: text.labelLarge),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _servings(double s) {
    final n = s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(1);
    return '$n ${s == 1 ? 'serving' : 'servings'}';
  }
}

/// Today's suggested meals for the user's diet and calorie target, with
/// "Shuffle" for another combination and one-tap logging per meal.
class _GoalCard extends ConsumerWidget {
  const _GoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final goal = ref.watch(weightGoalProvider);
    final weight = ref.watch(profileProvider)!.weightKg;
    void open() => SheetFrame.show<void>(context, const GoalSheet());

    if (goal == null) {
      return Pressable(
        onTap: open,
        child: GlassCard(
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Set a weight goal'), style: text.titleSmall),
                    Text(tr('Pick a target and a date — we\'ll set a safe calorie pace.'), style: text.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final pace = goal.pace(weight, now);
    final left = (goal.targetKg - weight).abs();
    final daysLeft = math.max(0, goal.deadline.difference(now).inDays);
    return Pressable(
      onTap: open,
      child: GlassCard(
        glow: pace == GoalPace.tooFast ? AppColors.danger : AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${goal.targetKg.toStringAsFixed(1)} kg by ${DateFormat.MMMd().format(goal.deadline)}',
                    style: text.titleSmall,
                  ),
                ),
                Text(
                  switch (pace) {
                    GoalPace.maintain => 'On target',
                    GoalPace.realistic => 'Realistic',
                    GoalPace.ambitious => 'Ambitious',
                    GoalPace.tooFast => 'Capped for safety',
                  },
                  style: text.labelMedium?.copyWith(
                    color: pace == GoalPace.tooFast ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress(weight),
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceHigh,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              left < 0.1
                  ? 'You\'ve reached your goal. Set a new one or keep it steady.'
                  : '${left.toStringAsFixed(1)} kg to go · $daysLeft days left · '
                        '${goal.neededPerWeek(weight, now).abs().toStringAsFixed(2)} kg a week',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final log = ref.watch(weightLogProvider);
    final weight = ref.watch(profileProvider)!.weightKg;
    final points = (log.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).reversed.take(30).toList().reversed;
    final values = [for (final p in points) p.value];
    final change = values.length >= 2 ? values.last - values.first : null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${weight.toStringAsFixed(1)} kg', style: text.titleMedium),
                    Text(
                      change == null
                          ? 'Log your weight to see your trend'
                          : '${change > 0
                                    ? '+'
                                    : change < 0
                                    ? '−'
                                    : ''}${change.abs().toStringAsFixed(1)} kg '
                                'over ${values.length} weigh-ins',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => SheetFrame.show<void>(context, const WeighInSheet()),
                child: Text(tr('Log weight')),
              ),
            ],
          ),
          if (values.length >= 2) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 70,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(values)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min) - 0.5, hi = values.reduce(math.max) + 0.5;
    Offset at(int i) => Offset(size.width * i / (values.length - 1), size.height * (1 - (values[i] - lo) / (hi - lo)));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = AppColors.primarySoft);
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true; // cheap, and colours follow the season
}

class _LearnRow extends StatelessWidget {
  const _LearnRow();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: Nutrient.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final n = Nutrient.values[i];
          return Pressable(
            onTap: () => showNutrientExplainer(context, n),
            child: SizedBox(
              width: 132,
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(n.icon, color: AppColors.primary, size: 22),
                    const Spacer(),
                    Text('What is ${n.label.toLowerCase()}?', style: text.titleSmall, maxLines: 2),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
