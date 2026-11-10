import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../diet/domain/food.dart';
import '../diet/widgets/sheet_frame.dart';
import 'domain/food_facts.dart';
import 'widgets/guide_card.dart';

/// Which foods are rich in what, per 100 g: rank every food by a nutrient, or
/// put two foods side by side.
class FoodGuideScreen extends ConsumerStatefulWidget {
  const FoodGuideScreen({super.key});

  @override
  ConsumerState<FoodGuideScreen> createState() => _FoodGuideScreenState();
}

class _FoodGuideScreenState extends ConsumerState<FoodGuideScreen> {
  int _mode = 0; // 0 rank, 1 compare
  FactNutrient _nutrient = FactNutrient.protein;
  int _diet = 0; // 0 all, 1 vegetarian, 2 vegan
  FoodFact? _a, _b;

  static const _dietNames = ['All foods', 'Vegetarian', 'Vegan'];

  bool _fits(FoodFact f) => switch (_diet) {
    1 => f.cls == FoodClass.vegan || f.cls == FoodClass.veg,
    2 => f.cls == FoodClass.vegan,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Food guide'))),
      body: PageBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GuideCard(
              id: 'foodguide',
              title: tr('How to use the food guide'),
              steps: [
                'Tap a nutrient, like Protein or Carbs, to see which foods have the most in 100 g.',
                'Tap any food to see everything in it.',
                'Switch to Compare to put two foods side by side, for example watermelon and sunflower seeds.',
              ],
            ),
            SegmentedPills(
              options: const ['Rank foods', 'Compare'],
              index: _mode,
              onChanged: (i) => setState(() => _mode = i),
            ),
            const SizedBox(height: 14),
            if (_mode == 0) ..._rank(text) else ..._compare(text),
            const SizedBox(height: 18),
            Text(
              tr(
                'All amounts are per 100 g of the food as listed (raw, cooked or dry). Values are typical figures '
                'from standard food tables and are rounded. Home cooking and brands vary, so use this as a guide. '
                'Dry foods look richer because cooking adds water.',
              ),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rank(TextTheme text) {
    final list = rankFoods(_nutrient, fits: _fits);
    final best = list.isEmpty ? 1.0 : (_nutrient.of(list.first) ?? 1.0);
    final cut = _nutrient.cutoffs;
    return [
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: FactNutrient.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final n = FactNutrient.values[i];
            return ChoicePill(label: n.label, selected: n == _nutrient, onTap: () => setState(() => _nutrient = n));
          },
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          for (final (i, d) in _dietNames.indexed)
            ChoicePill(label: d, selected: _diet == i, onTap: () => setState(() => _diet = i)),
        ],
      ),
      const SizedBox(height: 14),
      GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_nutrient.icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_nutrient.label}: ${_nutrient.tagline}', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(_nutrient.why, style: text.bodySmall),
                  if (cut != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Rich = ${_fmt(cut.high)} ${_nutrient.unit} or more in 100 g. Some = ${_fmt(cut.source)} to ${_fmt(cut.high)}.',
                      style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (list.isEmpty)
        Text(tr('No foods match.'), style: text.bodyMedium)
      else
        for (final (i, f) in list.indexed)
          _RankRow(rank: i + 1, food: f, nutrient: _nutrient, best: best, onTap: () => _detail(f)),
    ];
  }

  List<Widget> _compare(TextTheme text) {
    Widget picker(String label, FoodFact? f, ValueChanged<FoodFact> pick) => Expanded(
      child: Pressable(
        onTap: () async {
          final r = await SheetFrame.show<FoodFact>(context, _FoodPicker(exclude: f));
          if (r != null) pick(r);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: f == null ? AppColors.primary : AppColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelSmall),
              const SizedBox(height: 4),
              Text(f?.name ?? 'Tap to choose', style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (f != null) Text(f.state.label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
    final a = _a, b = _b;
    return [
      Row(
        children: [
          picker('Food 1', a, (f) => setState(() => _a = f)),
          const SizedBox(width: 10),
          picker('Food 2', b, (f) => setState(() => _b = f)),
        ],
      ),
      const SizedBox(height: 14),
      if (a == null || b == null)
        Text(tr('Choose two foods to compare them per 100 g.'), style: text.bodyMedium)
      else ...[
        for (final n in FactNutrient.values) _CompareRow(nutrient: n, a: a, b: b),
        if (a.state != b.state)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Careful: ${a.name} is ${a.state.label} and ${b.name} is ${b.state.label}. Cooking adds water, so '
              'compare like with like where you can.',
              style: text.bodySmall?.copyWith(color: AppColors.amber),
            ),
          ),
      ],
    ];
  }

  void _detail(FoodFact f) => SheetFrame.show<void>(context, _DetailSheet(food: f));
}

String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

String _value(FactNutrient n, double v) =>
    '${v >= 100 || v == v.roundToDouble() ? v.round() : v.toStringAsFixed(1)} ${n.unit}';

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.food,
    required this.nutrient,
    required this.best,
    required this.onTap,
  });

  final int rank;
  final FoodFact food;
  final FactNutrient nutrient;
  final double best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = nutrient.of(food)!;
    final band = nutrient.band(v);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('$rank', style: text.labelMedium?.copyWith(color: AppColors.textMuted)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(food.name, style: text.titleSmall, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Text(food.state.label, style: text.bodySmall?.copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: best <= 0 ? 0 : (v / best).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceHigh,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_value(nutrient, v), style: text.titleSmall),
                if (band != null) Text(band, style: text.labelSmall?.copyWith(color: AppColors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.nutrient, required this.a, required this.b});

  final FactNutrient nutrient;
  final FoodFact a;
  final FoodFact b;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final va = nutrient.of(a), vb = nutrient.of(b);
    if (va == null && vb == null) return const SizedBox.shrink();
    final top = [va ?? 0, vb ?? 0].reduce((x, y) => x > y ? x : y);
    Widget bar(double? v, bool wins) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v == null ? 'not listed' : _value(nutrient, v),
            style: text.titleSmall?.copyWith(color: wins ? AppColors.primary : AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v == null || top <= 0 ? 0 : (v / top).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.surfaceHigh,
              color: wins ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
    final aWins = va != null && (vb == null || va > vb);
    final bWins = vb != null && (va == null || vb > va);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nutrient.label, style: text.labelMedium),
          const SizedBox(height: 4),
          Row(children: [bar(va, aWins), const SizedBox(width: 16), bar(vb, bWins)]),
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.food});

  final FoodFact food;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: food.name,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('In 100 g of ${food.state.label} ${food.name.toLowerCase()}', style: text.bodyMedium),
          if (food.note != null) ...[
            const SizedBox(height: 4),
            Text(food.note!, style: text.bodySmall?.copyWith(color: AppColors.amber)),
          ],
          const SizedBox(height: 12),
          for (final n in FactNutrient.values)
            if (n.of(food) != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(n.icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(n.label, style: text.bodyMedium)),
                    if (n.band(n.of(food)!) != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(n.band(n.of(food)!)!, style: text.labelSmall?.copyWith(color: AppColors.primary)),
                      ),
                    Text(_value(n, n.of(food)!), style: text.titleSmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker({this.exclude});

  final FoodFact? exclude;

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = [
      for (final f in foodFacts)
        if (q.isEmpty || f.name.toLowerCase().contains(q)) f,
    ];
    return SheetFrame(
      title: tr('Choose a food'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('Search foods')),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in list)
                  ListTile(
                    title: Text(f.name),
                    subtitle: Text('${f.state.label} · ${f.group.label}'),
                    onTap: () => Navigator.of(context).pop(f),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
