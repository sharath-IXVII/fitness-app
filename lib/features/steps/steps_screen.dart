import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/week_bars.dart';
import '../profile/profile_providers.dart';
import 'domain/step_fusion.dart';
import 'steps_providers.dart';

/// Today's steps and distance: one merged count from the phone's motion
/// sensors (step counter, accelerometer, gyroscope), with GPS added when the
/// user allows location. Vehicle and bike time is left out.
class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(stepsProvider.notifier).start();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = ref.watch(stepsProvider);
    final targets = ref.watch(targetsProvider);
    final f = NumberFormat.decimalPattern();
    final goal = targets?.steps ?? 8000;
    final stride = targets?.strideM ?? 0.72;
    final day = s.day;
    final km = day.distanceMeters(stride) / 1000;
    final kcal = (km * (targets?.kcalPerKm ?? 35)).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Steps')),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: ProgressRing(
                progress: day.total / goal,
                color: AppColors.primary,
                size: 200,
                stroke: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk_rounded, color: AppColors.primary, size: 22),
                    AnimatedNumber(day.total, style: text.displaySmall),
                    Text('of ${f.format(goal)} steps', style: text.bodySmall),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 14),
            Center(child: _MotionChip(motion: s.motion)),
            const SizedBox(height: 18),
            Row(
              children: [
                _Stat(label: 'Distance today', value: '${km.toStringAsFixed(2)} km'),
                const SizedBox(width: 10),
                _Stat(label: 'Calories burned', value: '$kcal kcal'),
              ],
            ),
            if (targets != null) ...[
              const SizedBox(height: 14),
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.flag_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your daily goal', style: text.titleSmall),
                          Text(
                            '${targets.walkKm.toStringAsFixed(1)} km · ${f.format(targets.steps)} steps · '
                            'about ${targets.walkKcal} kcal',
                            style: text.bodyMedium,
                          ),
                          Text('Set from your height and weight', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _LocationCard(
              on: s.useLocation,
              tracking: s.gpsTracking,
              onChanged: (v) async {
                final ok = await ref.read(stepsProvider.notifier).setUseLocation(v);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location is off or not allowed, so steps use motion sensors only.')),
                  );
                }
              },
            ),
            if (s.permissionDenied) ...[
              const SizedBox(height: 14),
              GlassCard(
                glow: AppColors.danger,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Allow "Physical activity" so FittArc can count steps all day and spot bike or car rides.',
                        style: text.bodySmall,
                      ),
                    ),
                    TextButton(onPressed: () => ref.read(stepsProvider.notifier).start(), child: const Text('Allow')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('This week', style: text.titleMedium),
            const SizedBox(height: 12),
            GlassCard(
              child: WeekBars(
                days: ref.watch(weekStepsProvider),
                goal: goal,
                format: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your steps combine your phone\'s step counter with its accelerometer and gyroscope. If you allow '
              'location, GPS adds real distance too. Bumps in a vehicle or on a bike aren\'t counted.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionChip extends StatelessWidget {
  const _MotionChip({required this.motion});

  final Motion motion;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (motion) {
      Motion.walking => (Icons.directions_walk_rounded, 'Walking'),
      Motion.running => (Icons.directions_run_rounded, 'Running'),
      Motion.cycling => (Icons.pedal_bike_rounded, 'On a bike · steps paused'),
      Motion.vehicle => (Icons.directions_car_rounded, 'In a vehicle · steps paused'),
      Motion.still => (Icons.accessibility_new_rounded, 'Still'),
      Motion.unknown => (Icons.sensors_rounded, 'Detecting activity…'),
    };
    final paused = motion == Motion.cycling || motion == Motion.vehicle;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: paused ? AppColors.danger.withValues(alpha: 0.08) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: paused ? AppColors.danger : AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: paused ? AppColors.danger : AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(value, style: text.titleMedium),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Opt-in switch for merging GPS with the step sensor.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.on, required this.tracking, required this.onChanged});

  final bool on;
  final bool tracking;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(on ? Icons.my_location_rounded : Icons.location_disabled_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use GPS for better distance', style: text.titleSmall),
                Text(
                  !on
                      ? 'Off: motion sensors only, best for battery'
                      : tracking
                      ? 'On: GPS is helping right now'
                      : 'On: GPS helps while the app is open',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(value: on, onChanged: onChanged),
        ],
      ),
    );
  }
}
