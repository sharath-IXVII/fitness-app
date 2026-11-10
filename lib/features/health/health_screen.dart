import '../../core/i18n/i18n.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../diet/diet_providers.dart';
import '../diet/widgets/sheet_frame.dart';
import '../profile/profile_providers.dart';
import 'domain/body.dart';
import 'domain/health.dart';
import 'health_providers.dart';
import 'widgets/body_check_sheet.dart';
import 'widgets/health_widgets.dart';

/// Health: the camera heart-rate estimate, a watch, height, weight and BMI,
/// and the food guide. A wellness page: no medical values are logged.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    final sections = <Widget>[
      Text(tr('Health'), style: text.headlineMedium),
      Text(tr('Your heart, body and food, in one place.'), style: text.bodyMedium),
      const SizedBox(height: 14),
      const _HonestNote(),
      const SizedBox(height: 16),
      const _HeartRateCard(),
      const SizedBox(height: 12),
      const _WatchCard(),
      const SizedBox(height: 12),
      const _BodyCard(),
      const SizedBox(height: 12),
      const _FoodGuideCard(),
      const SizedBox(height: 22),
      for (final k in ReadingKind.values) ...[_KindCard(kind: k), const SizedBox(height: 12)],
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
              s.animate(delay: (i < 8 ? i * 30 : 0).ms).fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
          ],
        ),
      ),
    );
  }
}

/// Opens the per-100 g food guide.
class _FoodGuideCard extends StatelessWidget {
  const _FoodGuideCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.foodGuide),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Food guide'), style: text.titleMedium),
                  Text(tr('Which foods are rich in carbs, protein, fibre, vitamins and water, per 100 g.'),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tr('Heart rate can be estimated with your camera, and it is approximate. FittArc is for general fitness '
              'and wellness. It is not a medical device and this is not medical advice.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Measure heart rate with the camera.
class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.heartRate),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.favorite_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Measure heart rate'), style: text.titleMedium),
                  Text(tr('Press your fingertip on the back camera for 30 seconds. An approximate estimate.'),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Watch: live heart rate and Health Connect.
class _WatchCard extends ConsumerWidget {
  const _WatchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final week = ref.watch(weekArcProvider);
    return Pressable(
      onTap: () => context.push(Routes.watch),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.watch_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Connect your watch'), style: text.titleMedium),
                  Text(
                    week > 0
                        ? '${week.toStringAsFixed(0)} Arc minutes this week. Live heart rate and watch data.'
                        : 'Live heart rate by Bluetooth, plus steps and sleep from your watch app.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Height, weight and BMI.
class _BodyCard extends ConsumerWidget {
  const _BodyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    if (p == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final value = bmi(p.weightKg, p.heightCm);
    final rating = rateBmi(value, age: p.age);
    final range = healthyWeightRange(p.heightCm);
    final weights = ref.watch(weightLogProvider);
    final dates = weights.keys.toList()..sort();
    final trend = [for (final d in dates.reversed.take(12).toList().reversed) weights[d]!];
    final color = switch (rating.band) {
      BmiBand.healthy => const Color(0xFF2E8B57),
      BmiBand.under => const Color(0xFF2F7DBE),
      BmiBand.over => const Color(0xFFD9A100),
      BmiBand.obese => const Color(0xFFE0762A),
      null => AppColors.textSecondary,
    };
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Height and weight'), style: text.titleMedium)),
              TextButton(
                onPressed: () => SheetFrame.show<void>(context, const _BodySheet()),
                child: Text(tr('Update')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Stat('Height', '${p.heightCm.toStringAsFixed(p.heightCm % 1 == 0 ? 0 : 1)} cm'),
              _Stat('Weight', '${p.weightKg.toStringAsFixed(p.weightKg % 1 == 0 ? 0 : 1)} kg'),
              _Stat('BMI', value.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  rating.label,
                  style: text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              if (p.age >= 18) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Healthy for your height: ${range.min.round()} to ${range.max.round()} kg',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(rating.advice, style: text.bodySmall),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: () => SheetFrame.show<void>(context, const BodyCheckSheet()),
            icon: const Icon(Icons.accessibility_new_rounded),
            label: Text(tr('Body check: body fat and healthy weight')),
          ),
          if (trend.length >= 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(painter: WavePainter(trend, AppColors.primary)),
            ),
            Text('Your last ${trend.length} weigh-ins', style: text.bodySmall),
          ],
          const SizedBox(height: 6),
          Text(tr('A phone cannot weigh or measure you, so type in your height and weight. BMI is a rough guide and '
            'does not see muscle.'),
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall),
          Text(value, style: text.titleLarge),
        ],
      ),
    );
  }
}

class _BodySheet extends ConsumerStatefulWidget {
  const _BodySheet();

  @override
  ConsumerState<_BodySheet> createState() => _BodySheetState();
}

class _BodySheetState extends ConsumerState<_BodySheet> {
  late final _h = TextEditingController(text: _fmt(ref.read(profileProvider)?.heightCm));
  late final _w = TextEditingController(text: _fmt(ref.read(profileProvider)?.weightKg));
  String? _error;

  static String _fmt(double? v) => v == null ? '' : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final h = double.tryParse(_h.text.trim().replaceAll(',', '.'));
    final w = double.tryParse(_w.text.trim().replaceAll(',', '.'));
    if (h == null || w == null) return setState(() => _error = 'Enter both your height and your weight.');
    if (h < heightRangeCm.$1 || h > heightRangeCm.$2) {
      return setState(
        () => _error = 'Height should be between ${heightRangeCm.$1.round()} and ${heightRangeCm.$2.round()} cm.',
      );
    }
    if (w < weightRangeKg.$1 || w > weightRangeKg.$2) {
      return setState(
        () => _error = 'Weight should be between ${weightRangeKg.$1.round()} and ${weightRangeKg.$2.round()} kg.',
      );
    }
    final p = ref.read(profileProvider);
    if (p != null && p.heightCm != h) await ref.read(profileProvider.notifier).save(p.copyWith(heightCm: h));
    // Logging the weight also updates the profile, so calorie and water targets follow it.
    await ref.read(weightLogProvider.notifier).log(w);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget field(TextEditingController c, String label) => TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() => _error = null),
    );
    return SheetFrame(
      title: tr('Height and weight'),
      footer: FilledButton(onPressed: _save, child: Text(tr('Save'))),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        children: [
          Text(tr('Weigh yourself in the morning, before eating, for the most comparable numbers.'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 14),
          field(_h, 'Height (cm)'),
          const SizedBox(height: 12),
          field(_w, 'Weight (kg)'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

/// The latest reading of one kind, its trend, and the history.
class _KindCard extends ConsumerWidget {
  const _KindCard({required this.kind});

  final ReadingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(readingsOfProvider(kind));
    if (list.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final latest = list.first;
    final rating = latest.rating;
    return Pressable(
      onTap: () => SheetFrame.show<void>(context, _HistorySheet(kind: kind)),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        glow: rating.needsCare ? rating.level.color : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kind.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(kind.label, style: text.titleSmall)),
                RatingChip(rating: rating),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(latest.display, style: text.headlineMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${kind.unit} · ${_when(latest.at)}',
                      style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Sparkline(kind: kind, readings: list),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime at) {
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = DateFormat('h:mm a').format(at);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'today $time';
  if (diff == 1) return 'yesterday $time';
  return '${DateFormat('d MMM').format(at)} $time';
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({required this.kind});

  final ReadingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final list = ref.watch(readingsOfProvider(kind));
    return SheetFrame(
      title: kind.label,
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(tr('No readings yet.'), style: text.bodyMedium),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text(list.first.rating.advice, style: text.bodyMedium),
                const SizedBox(height: 10),
                for (final r in list.take(60))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Row(
                      children: [
                        Text('${r.display} ${kind.unit}', style: text.titleSmall),
                        const SizedBox(width: 10),
                        RatingChip(rating: r.rating),
                      ],
                    ),
                    subtitle: Text([_when(r.at)].join(' · ')),
                    trailing: IconButton(
                      tooltip: tr('Delete this reading'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(healthLogProvider.notifier).remove(r.id);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
