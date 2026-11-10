import '../../../core/i18n/i18n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../diet/widgets/sheet_frame.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/profile_providers.dart';
import '../domain/body.dart';

/// Where body-check measurements are kept (also backed up).
const bodyCheckKey = 'body.check.v1';
const _key = bodyCheckKey;

/// Body check: a body-fat estimate from a tape measure, healthy weight for
/// your height and waist-to-height. Wellness estimates, not a diagnosis.
class BodyCheckSheet extends ConsumerStatefulWidget {
  const BodyCheckSheet({super.key});

  @override
  ConsumerState<BodyCheckSheet> createState() => _BodyCheckSheetState();
}

class _BodyCheckSheetState extends ConsumerState<BodyCheckSheet> {
  final _waist = TextEditingController();
  final _neck = TextEditingController();
  final _hip = TextEditingController();

  @override
  void initState() {
    super.initState();
    try {
      final j = jsonDecode(ref.read(sharedPrefsProvider).getString(_key) ?? '{}') as Map<String, dynamic>;
      _waist.text = '${j['waist'] ?? ''}';
      _neck.text = '${j['neck'] ?? ''}';
      _hip.text = '${j['hip'] ?? ''}';
    } catch (_) {}
  }

  @override
  void dispose() {
    _waist.dispose();
    _neck.dispose();
    _hip.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v < 20 || v > 250 ? null : v;
  }

  void _save() => ref
      .read(sharedPrefsProvider)
      .setString(_key, jsonEncode({'waist': _num(_waist), 'neck': _num(_neck), 'hip': _num(_hip)}));

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider);
    if (p == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final female = p.gender == Gender.female;
    final waist = _num(_waist), neck = _num(_neck), hip = _num(_hip);
    final fat = waist == null || neck == null
        ? null
        : navyBodyFat(female: female, heightCm: p.heightCm, waistCm: waist, neckCm: neck, hipCm: hip);
    final range = healthyWeightRange(p.heightCm);
    final whtr = waist == null ? null : waistToHeight(waist, p.heightCm);

    Widget field(TextEditingController c, String label, String help) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, helperText: help, suffixText: 'cm'),
        onChanged: (_) {
          setState(() {});
          _save();
        },
      ),
    );

    return SheetFrame(
      title: tr('Body check'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Use a soft tape measure, standing relaxed. These are estimates for your fitness, not a medical test.'),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 14),
            field(_waist, 'Waist', female ? 'At the narrowest point' : 'At the belly button'),
            field(_neck, 'Neck', 'Just below the Adam\'s apple / voice box'),
            if (female) field(_hip, 'Hips', 'At the widest point'),
            const SizedBox(height: 6),
            _Result(
              title: tr('Body fat (estimate)'),
              value: fat == null ? '–' : '${fat.toStringAsFixed(1)} %',
              note: fat == null ? 'Add your measurements above.' : bodyFatBand(fat, female: female),
            ),
            if (p.age >= 18)
              _Result(
                title: 'Healthy weight for ${p.heightCm.round()} cm',
                value: '${range.min.round()}–${range.max.round()} kg',
                note: p.weightKg < range.min
                    ? 'You are ${(range.min - p.weightKg).toStringAsFixed(1)} kg below it.'
                    : p.weightKg > range.max
                    ? 'You are ${(p.weightKg - range.max).toStringAsFixed(1)} kg above it.'
                    : 'You are in it. Well done!',
              ),
            if (whtr != null)
              _Result(
                title: tr('Waist to height'),
                value: whtr.toStringAsFixed(2),
                note: whtr < 0.5
                    ? 'Under 0.5: a healthy sign.'
                    : 'Over 0.5. Daily walks and less fried and sugary food help bring it down.',
              ),
            const SizedBox(height: 10),
            Text(tr('Body fat uses the U.S. Navy tape method; it is usually within 3–4 points of a lab scan. A fitter body '
              'is good for your heart and energy.'),
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            GradientButton(label: tr('Done'), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.title, required this.value, required this.note});

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(note, style: text.bodySmall),
              ],
            ),
          ),
          Text(value, style: text.titleLarge?.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}
