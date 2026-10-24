import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/week_bars.dart';
import '../arcs/arc_providers.dart';
import '../arcs/domain/arc.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'water_providers.dart';

/// Phase 4: water intake with quick-add, undo and reminder settings.
class WaterScreen extends ConsumerStatefulWidget {
  const WaterScreen({super.key});

  @override
  ConsumerState<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends ConsumerState<WaterScreen> {
  final _added = <int>[];

  Future<void> _add(int ml) async {
    HapticFeedback.lightImpact();
    _added.add(ml);
    await ref.read(dailyLogsProvider.notifier).addWater(ml);
    setState(() {});
  }

  Future<void> _undo() async {
    if (_added.isEmpty) return;
    await ref.read(dailyLogsProvider.notifier).addWater(-_added.removeLast());
    setState(() {});
  }

  Future<void> _custom() async {
    final c = TextEditingController();
    final ml = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add water'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Amount', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, int.tryParse(c.text.trim())), child: const Text('Add')),
        ],
      ),
    );
    if (ml != null && ml > 0 && ml <= 3000) await _add(ml);
  }

  Future<void> _editGoal(int current) async {
    final c = TextEditingController(text: '$current');
    final result = await showDialog<int?>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Daily water goal'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Goal', suffixText: 'ml'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, -1), child: const Text('Use automatic')),
          TextButton(onPressed: () => Navigator.pop(d, int.tryParse(c.text.trim())), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    final goal = ref.read(waterGoalProvider.notifier);
    if (result == -1) {
      await goal.set(null);
    } else if (result >= 500 && result <= 8000) {
      await goal.set(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final custom = ref.watch(waterGoalProvider);
    final season = Season.forMonth(ref.watch(todayProvider).month);
    final log = ref.watch(todayLogProvider);
    final goal = ref.watch(targetsProvider)?.waterMl ?? 2500;
    final settings = ref.watch(waterSettingsProvider);
    final profile = ref.watch(profileProvider);
    final progress = log.waterMl / goal;
    String litres(int ml) => (ml / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water'),
        actions: [
          if (_added.isNotEmpty)
            TextButton.icon(onPressed: _undo, icon: const Icon(Icons.undo_rounded), label: const Text('Undo')),
        ],
      ),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(child: _Glass(progress: progress)),
            const SizedBox(height: 16),
            Center(child: Text('${litres(log.waterMl)} of ${litres(goal)} L', style: text.headlineSmall)),
            Center(
              child: Text(
                progress >= 1 ? 'Goal reached — nicely done.' : '${litres(math.max(0, goal - log.waterMl))} L to go',
                style: text.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => _editGoal(goal),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(custom == null ? 'Goal set for ${season.title} · change' : 'Your own goal · change'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (ml, label, icon) in [
                  (150, 'Cup', Icons.coffee_outlined),
                  (250, 'Glass', Icons.local_drink_outlined),
                  (500, 'Bottle', Icons.water_drop_outlined),
                ]) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () => _add(ml),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Icon(icon, color: AppColors.primary),
                            const SizedBox(height: 6),
                            Text('+$ml ml', style: text.titleSmall),
                            Text(label, style: text.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Pressable(
                    onTap: _custom,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(Icons.edit_outlined, color: AppColors.primary),
                          const SizedBox(height: 6),
                          Text('Custom', style: text.titleSmall),
                          Text('Any ml', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Reminders', style: text.titleMedium),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingToggle(
                    icon: Icons.notifications_none_rounded,
                    title: 'Remind me to drink',
                    subtitle: profile == null
                        ? null
                        : 'Between ${profile.wakeTime.format(context)} and ${profile.sleepTime.format(context)}, '
                              'with +250 ml buttons in the notification',
                    value: settings.reminders,
                    onChanged: (v) => ref.read(waterSettingsProvider.notifier).set(reminders: v),
                  ),
                  if (settings.reminders) ...[
                    const SizedBox(height: 10),
                    SegmentedPills(
                      options: const ['Every 1 h', '1.5 h', '2 h', '3 h'],
                      index: const [60, 90, 120, 180].indexOf(settings.everyMinutes).clamp(0, 3),
                      onChanged: (i) =>
                          ref.read(waterSettingsProvider.notifier).set(everyMinutes: const [60, 90, 120, 180][i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('This week', style: text.titleMedium),
            const SizedBox(height: 10),
            GlassCard(
              child: WeekBars(
                days: ref.watch(weekWaterProvider),
                goal: goal,
                format: (v) => v == 0 ? '' : litres(v.toInt()),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              custom == null
                  ? 'Your goal is about 35 ml per kg of body weight, plus extra on active days and in hot months '
                        '(${season.title}: +${season.waterBoostMl} ml). It changes by itself with the season.'
                  : 'You set this goal yourself. Tap "change" to go back to the automatic one.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A glass that fills smoothly to [progress], with a gentle surface wave.
class _Glass extends StatefulWidget {
  const _Glass({required this.progress});

  final double progress;

  @override
  State<_Glass> createState() => _GlassState();
}

class _GlassState extends State<_Glass> with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, level, _) => AnimatedBuilder(
        animation: _wave,
        builder: (_, _) => CustomPaint(size: const Size(150, 200), painter: _GlassPainter(level, _wave.value)),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.level, this.t);

  final double level;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Slightly tapered glass.
    final glass = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w * 0.86, h)
      ..lineTo(w * 0.14, h)
      ..close();
    canvas.drawPath(glass, Paint()..color = AppColors.surface);
    canvas.save();
    canvas.clipPath(glass);
    if (level > 0) {
      final top = h * (1 - level);
      final water = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 4) {
        water.lineTo(x, top + math.sin((x / w * 2 + t) * math.pi * 2) * 4);
      }
      water
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        water,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.water.withValues(alpha: 0.55), AppColors.water],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.restore();
    canvas.drawPath(
      glass,
      Paint()
        ..color = AppColors.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.level != level || old.t != t;
}
