import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/storage.dart';
import '../profile/domain/user_profile.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../streaks/domain/daily_log.dart';
import 'domain/food.dart';
import 'domain/meal_log.dart';
import 'domain/meal_plan.dart';
import 'domain/weight_goal.dart';

final _keyDate = DateFormat('yyyy-MM-dd');
String _mealsKey(DateTime d) => 'meals.v1.${_keyDate.format(d)}';
const _goalKey = 'goal.v1';
const _weightKey = 'weight.v1';

/// Today's logged food. Every change also updates the daily log (meals
/// covered and protein), which drives the score and the streak calendar.
class MealLogNotifier extends Notifier<List<MealEntry>> {
  DateTime _day = dayOnly(DateTime.now());

  @override
  List<MealEntry> build() {
    _day = dayOnly(DateTime.now());
    final raw = ref.read(sharedPrefsProvider).getString(_mealsKey(_day));
    if (raw == null) return const [];
    return [for (final j in jsonDecode(raw) as List) MealEntry.fromJson(j as Map<String, dynamic>)];
  }

  void _rollDay() {
    if (dayOnly(DateTime.now()) != _day) state = build();
  }

  Future<void> _save(List<MealEntry> next) async {
    state = next;
    await ref.read(sharedPrefsProvider).setString(_mealsKey(_day), jsonEncode([for (final e in next) e.toJson()]));
    final total = totalOf(next);
    await ref
        .read(dailyLogsProvider.notifier)
        .update((l) => l.copyWith(mealsLogged: mealsCovered(next), proteinG: total.protein.round()));
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> add(MealEntry e) async {
    _rollDay();
    await _save([...state, e]);
  }

  Future<void> addAll(Iterable<MealEntry> entries) async {
    _rollDay();
    await _save([...state, ...entries]);
  }

  Future<void> replace(MealEntry e) => _save([for (final x in state) x.id == e.id ? e : x]);

  Future<void> remove(String id) => _save([...state.where((e) => e.id != id)]);

  Future<void> clearAll() async {
    final prefs = ref.read(sharedPrefsProvider);
    for (final k in prefs.getKeys().where((k) => k.startsWith('meals.v1.')).toList()) {
      await prefs.remove(k);
    }
    state = const [];
  }
}

final mealLogProvider = NotifierProvider<MealLogNotifier, List<MealEntry>>(MealLogNotifier.new);

final mealTotalsProvider = Provider<Macros>((ref) => totalOf(ref.watch(mealLogProvider)));

/// Recently logged foods, most recent first, for one-tap re-adding.
final recentFoodsProvider = Provider<List<String>>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  ref.watch(mealLogProvider);
  final keys = prefs.getKeys().where((k) => k.startsWith('meals.v1.')).toList()..sort((a, b) => b.compareTo(a));
  final seen = <String>{};
  for (final k in keys.take(14)) {
    final list = jsonDecode(prefs.getString(k) ?? '[]') as List;
    for (final j in list.reversed) {
      final id = (j as Map<String, dynamic>)['food'] as String?;
      if (id != null) seen.add(id);
      if (seen.length >= 8) return seen.toList();
    }
  }
  return seen.toList();
});

class WeightGoalNotifier extends Notifier<WeightGoal?> {
  @override
  WeightGoal? build() {
    final raw = ref.read(sharedPrefsProvider).getString(_goalKey);
    return raw == null ? null : WeightGoal.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> set(WeightGoal? goal) async {
    final prefs = ref.read(sharedPrefsProvider);
    if (goal == null) {
      await prefs.remove(_goalKey);
    } else {
      await prefs.setString(_goalKey, jsonEncode(goal.toJson()));
    }
    state = goal;
  }
}

final weightGoalProvider = NotifierProvider<WeightGoalNotifier, WeightGoal?>(WeightGoalNotifier.new);

/// Weigh-ins by day. Logging one also updates the profile, so every target
/// (calories, protein, water) follows the user's current weight.
class WeightLogNotifier extends Notifier<Map<DateTime, double>> {
  @override
  Map<DateTime, double> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_weightKey);
    if (raw == null) return const {};
    return {
      for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
        DateTime.parse(e.key): (e.value as num).toDouble(),
    };
  }

  Future<void> log(double kg, {DateTime? on}) async {
    final d = dayOnly(on ?? DateTime.now());
    state = {...state, d: kg};
    await ref
        .read(sharedPrefsProvider)
        .setString(_weightKey, jsonEncode({for (final e in state.entries) _keyDate.format(e.key): e.value}));
    final profile = ref.read(profileProvider);
    final latest = (state.keys.toList()..sort()).last;
    if (profile != null && d == latest) await ref.read(profileProvider.notifier).save(profile.copyWith(weightKg: kg));
  }

  Future<void> clearAll() async {
    await ref.read(sharedPrefsProvider).remove(_weightKey);
    state = const {};
  }
}

final weightLogProvider = NotifierProvider<WeightLogNotifier, Map<DateTime, double>>(WeightLogNotifier.new);

/// Daily nutrition targets. Without a weight goal they follow the profile's
/// goal; with one, calories follow the pace needed to hit the deadline
/// (within safe limits).
class DietTargets {
  const DietTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.adjustment,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;

  /// Daily calorie change from maintenance set by the weight goal.
  final int? adjustment;
}

final dietTargetsProvider = Provider<DietTargets?>((ref) {
  final profile = ref.watch(profileProvider);
  final t = ref.watch(targetsProvider);
  if (profile == null || t == null) return null;
  final goal = ref.watch(weightGoalProvider);
  var calories = t.calories;
  int? adjustment;
  if (goal != null) {
    adjustment = goal.dailyAdjustment(profile.weightKg, DateTime.now());
    final floor = profile.gender == Gender.male ? 1500 : 1200;
    calories = math.max(floor, t.tdee + adjustment);
  }
  final fat = (calories * 0.25 / 9).round();
  final carbs = math.max(0, ((calories - t.proteinG * 4 - fat * 9) / 4).round());
  return DietTargets(
    calories: calories,
    protein: t.proteinG,
    carbs: carbs,
    fat: fat,
    fiber: (calories / 1000 * 14).round(),
    adjustment: adjustment,
  );
});

/// Bumped by "Shuffle" to get a different plan for today.
class PlanShuffle extends Notifier<int> {
  @override
  int build() => 0;

  void next() => state++;
}

final planShuffleProvider = NotifierProvider<PlanShuffle, int>(PlanShuffle.new);

final todayPlanProvider = Provider<List<PlannedMeal>>((ref) {
  final profile = ref.watch(profileProvider);
  final t = ref.watch(dietTargetsProvider);
  if (profile == null || t == null) return const [];
  final now = DateTime.now();
  final seed = now.year * 10000 + now.month * 100 + now.day + ref.watch(planShuffleProvider) * 7919;
  return buildDayPlan(diet: profile.diet, calories: t.calories, proteinTarget: t.protein, seed: seed);
});
