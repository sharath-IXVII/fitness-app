import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../profile/profile_providers.dart';
import '../diet_providers.dart';
import '../domain/food.dart';
import '../domain/food_db.dart';
import '../domain/meal_log.dart';
import 'sheet_frame.dart';

/// Search the food list (filtered to the user's diet), pick servings and
/// add to a meal. Also supports a custom food with typed-in macros.
class FoodSearchSheet extends ConsumerStatefulWidget {
  const FoodSearchSheet({super.key, required this.meal, this.initialQuery});

  final MealType meal;

  /// Pre-filled search, e.g. a dish the camera recognised.
  final String? initialQuery;

  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

enum _Filter { all, mine, recent, protein, snack }

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  late MealType _meal = widget.meal;
  late final _query = TextEditingController(text: widget.initialQuery);
  _Filter _filter = _Filter.all;
  Food? _picked;
  double _servings = 1;
  bool _custom = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Food> _results() {
    final diet = ref.read(profileProvider)?.diet;
    final q = _query.text.trim().toLowerCase();
    final mine = ref.read(myFoodsProvider);
    final byId = ref.read(allFoodsByIdProvider);
    // Saved foods are the user's own, so they skip the diet filter.
    bool fits(Food f) => f.tags.contains('mine') || diet == null || f.cls.fits(diet);
    Iterable<Food> list = switch (_filter) {
      _Filter.mine => mine,
      _Filter.recent => [for (final id in ref.read(recentFoodsProvider)) ?byId[id]],
      _Filter.protein => [...mine, ...foods].where((f) => f.highProtein),
      _Filter.snack => foods.where((f) => f.tags.contains('snack')),
      _Filter.all => [...mine, ...foods],
    };
    list = list.where(fits);
    if (q.isNotEmpty) list = list.where((f) => f.name.toLowerCase().contains(q));
    return list.toList();
  }

  Future<void> _forget(Food f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove ${f.name}?'),
        content: const Text('It will no longer appear in My foods. Meals you already logged stay as they are.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(myFoodsProvider.notifier).remove(f.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _add(MealEntry e) async {
    HapticFeedback.lightImpact();
    await ref.read(mealLogProvider.notifier).add(e);
    if (mounted) Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return SheetFrame(
      title: _custom ? 'Custom food' : (picked?.name ?? 'Add food'),
      action: picked != null || _custom
          ? IconButton(
              tooltip: 'Back',
              onPressed: () => setState(() {
                _picked = null;
                _custom = false;
              }),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _custom
            ? _CustomFood(key: const ValueKey('custom'), meal: _meal, onAdd: _add)
            : picked == null
            ? _list(context)
            : _servingsView(context, picked),
      ),
    );
  }

  Widget _mealPills() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        for (final m in MealType.values) ...[
          ChoicePill(label: m.label, selected: _meal == m, onTap: () => setState(() => _meal = m)),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  Widget _list(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final results = _results();
    return Column(
      key: const ValueKey('list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mealPills(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search foods', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final (f, label) in [
                (_Filter.all, 'All'),
                if (ref.watch(myFoodsProvider).isNotEmpty) (_Filter.mine, 'My foods'),
                (_Filter.recent, 'Recent'),
                (_Filter.protein, 'High protein'),
                (_Filter.snack, 'Snacks'),
              ]) ...[
                ChoicePill(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            children: [
              for (final f in results)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(f.name, style: text.titleSmall),
                  subtitle: Text(
                    '${f.serving} · ${f.macros.kcal.round()} kcal · ${f.macros.protein.round()} g protein',
                    style: text.bodySmall,
                  ),
                  leading: f.tags.contains('mine')
                      ? Icon(Icons.bookmark_rounded, color: AppColors.accent, size: 20)
                      : null,
                  trailing: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  onTap: () => setState(() {
                    _picked = f;
                    _servings = 1;
                  }),
                  onLongPress: f.tags.contains('mine') ? () => _forget(f) : null,
                ),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    switch (_filter) {
                      _Filter.recent => 'Foods you log will show up here.',
                      _Filter.mine => 'Foods you save will show up here.',
                      _ => 'No foods match. Add it as a custom food below.',
                    },
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(Icons.edit_note_rounded, color: AppColors.primary),
                title: Text('Add a custom food', style: text.titleSmall),
                subtitle: Text('Type in the calories and macros from a label', style: text.bodySmall),
                onTap: () => setState(() => _custom = true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _servingsView(BuildContext context, Food f) {
    final text = Theme.of(context).textTheme;
    final m = f.macros.scale(_servings);
    return SingleChildScrollView(
      key: ValueKey(f.id),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mealPills(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1 serving = ${f.serving}', style: text.bodyMedium),
                const SizedBox(height: 14),
                ServingsStepper(value: _servings, onChanged: (v) => setState(() => _servings = v)),
                const SizedBox(height: 18),
                MacroSummary(macros: m),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Add to ${_meal.label.toLowerCase()}',
                  icon: Icons.add_rounded,
                  onPressed: () => _add(MealEntry.ofFood(MealLogNotifier.newId(), _meal, f, _servings)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// − 1.5 servings + in half steps.
class ServingsStepper extends StatelessWidget {
  const ServingsStepper({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    Widget btn(IconData icon, double next, bool enabled) => IconButton.filledTonal(
      style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft, foregroundColor: AppColors.primary),
      onPressed: enabled
          ? () {
              HapticFeedback.selectionClick();
              onChanged(next);
            }
          : null,
      icon: Icon(icon),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        btn(Icons.remove_rounded, value - 0.5, value > 0.5),
        SizedBox(
          width: 130,
          child: Column(
            children: [
              Text(label, style: text.headlineMedium),
              Text(value == 1 ? 'serving' : 'servings', style: text.bodySmall),
            ],
          ),
        ),
        btn(Icons.add_rounded, value + 0.5, value < 10),
      ],
    );
  }
}

/// kcal · protein · carbs · fat · fiber in a row of small tiles.
class MacroSummary extends StatelessWidget {
  const MacroSummary({super.key, required this.macros});

  final Macros macros;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final (label, v, unit) in [
          ('Calories', macros.kcal, ''),
          ('Protein', macros.protein, 'g'),
          ('Carbs', macros.carbs, 'g'),
          ('Fat', macros.fat, 'g'),
          ('Fiber', macros.fiber, 'g'),
        ])
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('${v.round()}$unit', style: text.titleSmall),
                  Text(label, style: text.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomFood extends ConsumerStatefulWidget {
  const _CustomFood({super.key, required this.meal, required this.onAdd});

  final MealType meal;
  final Future<void> Function(MealEntry) onAdd;

  @override
  ConsumerState<_CustomFood> createState() => _CustomFoodState();
}

class _CustomFoodState extends ConsumerState<_CustomFood> {
  final _name = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  bool _remember = true;
  final _fields = {
    for (final k in ['kcal', 'protein', 'carbs', 'fat', 'fiber']) k: TextEditingController(),
  };

  @override
  void dispose() {
    _name.dispose();
    _serving.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(String k) => double.tryParse(_fields[k]!.text.trim()) ?? 0;

  bool get _valid => _name.text.trim().isNotEmpty && _v('kcal') > 0 && _v('kcal') < 5000;

  Future<void> _submit() async {
    final macros = Macros(
      kcal: _v('kcal'),
      protein: _v('protein'),
      carbs: _v('carbs'),
      fat: _v('fat'),
      fiber: _v('fiber'),
    );
    final serving = _serving.text.trim().isEmpty ? '1 serving' : _serving.text.trim();
    String? foodId;
    if (_remember) {
      final food = Food(
        MyFoodsNotifier.newId(),
        _name.text.trim(),
        serving,
        FoodClass.veg,
        macros,
        tags: const {'mine'},
      );
      await ref.read(myFoodsProvider.notifier).add(food);
      foodId = food.id;
    }
    await widget.onAdd(
      MealEntry(
        id: MealLogNotifier.newId(),
        meal: widget.meal,
        name: _name.text.trim(),
        servings: 1,
        perServing: macros,
        foodId: foodId,
        serving: serving,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, String suffix) => InputDecoration(labelText: label, suffixText: suffix);
    Widget num(String k, String label, String suffix) => Expanded(
      child: TextField(
        controller: _fields[k],
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: deco(label, suffix),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Protein bar'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serving,
            decoration: const InputDecoration(labelText: 'Serving', hintText: 'e.g. 1 bar (40 g)'),
          ),
          const SizedBox(height: 12),
          Row(children: [num('kcal', 'Calories', 'kcal'), const SizedBox(width: 10), num('protein', 'Protein', 'g')]),
          const SizedBox(height: 12),
          Row(
            children: [
              num('carbs', 'Carbs', 'g'),
              const SizedBox(width: 10),
              num('fat', 'Fat', 'g'),
              const SizedBox(width: 10),
              num('fiber', 'Fiber', 'g'),
            ],
          ),
          const SizedBox(height: 8),
          SettingToggle(
            icon: Icons.bookmark_outline_rounded,
            title: 'Save to My foods',
            subtitle: 'Add it again later in one tap',
            value: _remember,
            onChanged: (v) => setState(() => _remember = v),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Add to ${widget.meal.label.toLowerCase()}',
            icon: Icons.add_rounded,
            onPressed: _valid ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Change servings or remove a logged item.
class EntryEditSheet extends ConsumerStatefulWidget {
  const EntryEditSheet({super.key, required this.entry});

  final MealEntry entry;

  @override
  ConsumerState<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<EntryEditSheet> {
  late double _servings = widget.entry.servings;
  late MealType _meal = widget.entry.meal;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: e.name,
      action: IconButton(
        tooltip: 'Remove',
        onPressed: () {
          ref.read(mealLogProvider.notifier).remove(e.id);
          Navigator.pop(context);
        },
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MealType.values)
                  ChoicePill(label: m.label, selected: _meal == m, onTap: () => setState(() => _meal = m)),
              ],
            ),
            if (e.serving != null) ...[
              const SizedBox(height: 14),
              Text('1 serving = ${e.serving}', style: text.bodyMedium),
            ],
            const SizedBox(height: 14),
            ServingsStepper(value: _servings, onChanged: (v) => setState(() => _servings = v)),
            const SizedBox(height: 18),
            MacroSummary(macros: e.perServing.scale(_servings)),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Save',
              icon: Icons.check_rounded,
              onPressed: () {
                ref.read(mealLogProvider.notifier).replace(e.copyWith(servings: _servings, meal: _meal));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
