import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../diet/diet_providers.dart';
import '../../diet/domain/food.dart';
import '../../diet/widgets/sheet_frame.dart';
import '../domain/recognition.dart';
import '../domain/scan_result.dart';

String _g(double v) => v >= 10 ? '${v.round()} g' : '${v.toStringAsFixed(1)} g';

/// The plate photo with a frame and name tag on each dish found.
class PlatePhoto extends StatelessWidget {
  const PlatePhoto({super.key, required this.image, required this.items, this.onTapItem});

  final Uint8List image;
  final List<ScannedItem> items;
  final ValueChanged<int>? onTapItem;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: LayoutBuilder(
          builder: (context, c) {
            final side = c.maxWidth;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(image, fit: BoxFit.cover, gaplessPlayback: true),
                for (final (i, item) in items.indexed)
                  ...() {
                    final tag = GestureDetector(
                      onTap: onTapItem == null ? null : () => onTapItem!(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
                        ),
                        child: Text(item.name, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    );
                    final b = item.box;
                    if (b == null) return [Positioned(left: 10, bottom: 10.0 + i * 30, child: tag)];
                    final rough = scanRegions.contains(b);
                    final ctr = b.center;
                    final r = rough
                        ? Rect.fromCenter(
                            center: Offset(ctr.dx * side, ctr.dy * side),
                            width: b.width * side * 0.62,
                            height: b.height * side * 0.62,
                          )
                        : Rect.fromLTWH(b.left * side, b.top * side, b.width * side, b.height * side);
                    return [
                      Positioned.fromRect(
                        rect: r,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary, width: 2.4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(left: r.left + 6, top: r.top + 6, child: tag),
                    ];
                  }(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Detected foods & nutrition (approx.)": one row per dish (tap to edit),
/// a row to add a dish the camera missed, and the plate total.
class NutritionTable extends StatelessWidget {
  const NutritionTable({super.key, required this.items, required this.onEdit, required this.onAdd});

  final List<ScannedItem> items;
  final ValueChanged<int> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = items.fold(const Macros(), (m, i) => m + i.scaled);
    final head = text.labelSmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    Widget cells(List<Widget> c) => Row(
      children: [
        for (final (i, w) in c.indexed) Expanded(flex: const [7, 4, 3, 3, 3][i], child: w),
      ],
    );
    Text num(String v, [TextStyle? s]) => Text(v, textAlign: TextAlign.right, style: s ?? text.bodyMedium);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('Detected foods & nutrition'), style: text.titleSmall)),
              Text(tr('(approx.)'), style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          cells([
            Text(tr('Food'), style: head),
            num('kcal', head),
            num(tr('Protein'), head),
            num(tr('Carbs'), head),
            num(tr('Fibre'), head),
          ]),
          const Divider(height: 14),
          for (final (i, item) in items.indexed)
            InkWell(
              onTap: () => onEdit(i),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: cells([
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted),
                        ],
                      ),
                      Text(
                        item.factor == 1
                            ? item.portion
                            : '${item.factor.toStringAsFixed(item.factor % 1 == 0 ? 0 : 1)} × ${item.portion}',
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  num('${item.scaled.kcal.round()}'),
                  num(_g(item.scaled.protein)),
                  num(_g(item.scaled.carbs)),
                  num(_g(item.scaled.fiber)),
                ]),
              ),
            ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(tr('Add a dish the camera missed')),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('≈ ${total.kcal.round()} kcal', style: text.titleLarge, maxLines: 1),
                    ),
                  ),
                  for (final (v, l) in [
                    (_g(total.protein), tr('Protein')),
                    (_g(total.carbs), tr('Carbs')),
                    (_g(total.fiber), tr('Fibre')),
                  ])
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(v, style: text.titleSmall),
                          Text(l, style: text.labelSmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Edit one dish: change what it is, how much, or remove it.
class DishEditSheet extends ConsumerStatefulWidget {
  const DishEditSheet({super.key, required this.item, this.alternatives = const []});

  final ScannedItem item;

  /// Other dishes the model thought it could be.
  final List<Food> alternatives;

  @override
  ConsumerState<DishEditSheet> createState() => _DishEditSheetState();
}

/// What the edit sheet returns: a changed item, or null to remove it.
typedef DishEdit = ({ScannedItem? item});

class _DishEditSheetState extends ConsumerState<DishEditSheet> {
  late ScannedItem _item = widget.item;

  static const _steps = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = _item.scaled;
    final i = _steps.indexWhere((s) => (s - _item.factor).abs() < 0.01);
    return SheetFrame(
      title: _item.name,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('How much did you eat?'), style: text.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: tr('Less'),
                  onPressed: i <= 0 ? null : () => setState(() => _item = _item.copyWith(factor: _steps[i - 1])),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_item.factor.toStringAsFixed(_item.factor % 1 == 0 ? 0 : 2).replaceAll(RegExp(r'0$'), '')} × ${_item.portion}',
                        textAlign: TextAlign.center,
                        style: text.titleMedium,
                      ),
                      Text(
                        '${m.kcal.round()} kcal · ${tr('Protein')} ${_g(m.protein)} · ${tr('Carbs')} ${_g(m.carbs)}',
                        style: text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: tr('More'),
                  onPressed: i < 0 || i >= _steps.length - 1
                      ? null
                      : () => setState(() => _item = _item.copyWith(factor: _steps[i + 1])),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(tr('Not this dish? Change it'), style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in widget.alternatives.where((f) => f.name != _item.name))
                  ActionChip(
                    label: Text(f.name),
                    onPressed: () => setState(
                      () => _item = ScannedItem.fromFood(f, 1, box: _item.box).copyWith(factor: _item.factor),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.search_rounded, size: 18),
                  label: Text(tr('Search dishes')),
                  onPressed: () async {
                    final f = await pickDish(context);
                    if (f != null) {
                      setState(() => _item = ScannedItem.fromFood(f, 1, box: _item.box).copyWith(factor: _item.factor));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => Navigator.of(context).pop<DishEdit>((item: _item)), child: Text(tr('Save'))),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop<DishEdit>((item: null)),
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              label: Text(tr('Remove from plate'), style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search the dish list and pick one (nothing is logged).
Future<Food?> pickDish(BuildContext context) => SheetFrame.show<Food>(context, const _DishPicker());

class _DishPicker extends ConsumerStatefulWidget {
  const _DishPicker();

  @override
  ConsumerState<_DishPicker> createState() => _DishPickerState();
}

class _DishPickerState extends ConsumerState<_DishPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(allFoodsByIdProvider).values.toList()..sort((a, b) => a.name.compareTo(b.name));
    final q = _q.toLowerCase();
    final shown = [
      for (final f in all)
        if (q.isEmpty || f.name.toLowerCase().contains(q)) f,
    ].take(60).toList();
    return SheetFrame(
      title: tr('Choose a dish'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Search dishes')),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in shown)
                  ListTile(
                    title: Text(f.name),
                    subtitle: Text('${f.serving} · ${f.macros.kcal.round()} kcal', style: text.bodySmall),
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
