import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/week_bars.dart';
import '../alarm/app_permissions.dart';
import '../profile/profile_providers.dart';
import 'domain/step_fusion.dart';
import 'steps_providers.dart';

/// Phase 4: verified steps from the phone's step sensor (with vehicle and
/// bike time removed) plus GPS walks.
class StepsScreen extends ConsumerStatefulWidget {
  const StepsScreen({super.key});

  @override
  ConsumerState<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends ConsumerState<StepsScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    ref.read(stepsProvider.notifier).start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(stepsProvider).walking) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _toggleWalk() async {
    final n = ref.read(stepsProvider.notifier);
    HapticFeedback.mediumImpact();
    if (ref.read(stepsProvider).walking) {
      await n.stopWalk();
      return;
    }
    if (!await n.startWalk() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Turn on location and allow FittiePi to use it to record a GPS walk.'),
          action: SnackBarAction(label: 'Settings', onPressed: AppPermissions.openSettings),
          persist: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = ref.watch(stepsProvider);
    final targets = ref.watch(targetsProvider);
    final goal = targets?.steps ?? 8000;
    final stride = targets?.strideM ?? 0.72;
    final day = s.day;
    final km = day.distanceMeters(stride) / 1000;
    final gpsExtra = (day.total - day.verified).clamp(0, 1 << 30);

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
                    Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                    AnimatedNumber(day.total, style: text.displaySmall),
                    Text('of ${NumberFormat.decimalPattern().format(goal)} steps', style: text.bodySmall),
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
                _Stat(label: 'Calories', value: '${(day.total * 0.04).round()} kcal'),
                const SizedBox(width: 10),
                _Stat(label: 'Stride', value: '${stride.toStringAsFixed(2)} m'),
              ],
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: [
                  _Row(
                    icon: Icons.phone_android_rounded,
                    label: 'Phone sensor',
                    hint: 'Hardware step counter',
                    value: day.sensor,
                  ),
                  Divider(height: 22, color: AppColors.stroke),
                  _Row(
                    icon: Icons.directions_car_outlined,
                    label: 'Removed',
                    hint: 'Counted while on a bike or in a vehicle',
                    value: day.removed == 0 ? 0 : -day.removed,
                  ),
                  Divider(height: 22, color: AppColors.stroke),
                  _Row(
                    icon: Icons.location_on_outlined,
                    label: 'Added by GPS',
                    hint: s.useLocation
                        ? 'Steps the sensor missed, from ${(day.gpsMeters / 1000).toStringAsFixed(2)} km of GPS'
                        : 'Turn on location below to use GPS too',
                    value: gpsExtra,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _LocationCard(
              on: s.useLocation,
              tracking: s.gpsTracking,
              onChanged: (v) async {
                final ok = await ref.read(stepsProvider.notifier).setUseLocation(v);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location is off or not allowed, so steps use the phone sensor only.'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            _WalkCard(state: s, stride: stride, onToggle: _toggleWalk),
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
                        'Allow "Physical activity" so FittiePi can count steps and spot bike or car rides.',
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
              'Steps come from your phone\'s step sensor, which counts all day. With location on, GPS also runs '
              'while the app is open: it adds steps the sensor missed, measures real distance and spots car or bike '
              'rides. Bumps in a vehicle or on a bike aren\'t counted.',
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

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.hint, required this.value});

  final IconData icon;
  final String label;
  final String hint;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final f = NumberFormat.decimalPattern();
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleSmall),
              Text(hint, style: text.bodySmall),
            ],
          ),
        ),
        Text(
          value < 0 ? '−${f.format(-value)}' : f.format(value),
          style: text.titleMedium?.copyWith(color: value < 0 ? AppColors.danger : AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _WalkCard extends StatelessWidget {
  const _WalkCard({required this.state, required this.stride, required this.onToggle});

  final StepsState state;
  final double stride;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final walking = state.walking;
    final elapsed = walking && state.walkStarted != null
        ? DateTime.now().difference(state.walkStarted!)
        : Duration.zero;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final km = state.walkMeters / 1000;
    final pace = km > 0.05 ? elapsed.inSeconds / km : 0;
    return GlassCard(
      glow: walking ? AppColors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(walking ? Icons.my_location_rounded : Icons.route_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(walking ? 'Recording GPS walk' : 'GPS walk', style: text.titleMedium)),
              if (walking)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 800.ms),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: walking
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Live(value: '$mm:$ss', label: 'Time'),
                        _Live(value: km.toStringAsFixed(2), label: 'km'),
                        _Live(value: '${(state.walkMeters / stride).round()}', label: 'steps'),
                        _Live(
                          value: pace == 0
                              ? '–'
                              : "${(pace ~/ 60)}'${(pace % 60).round().toString().padLeft(2, '0')}\"",
                          label: 'per km',
                        ),
                      ],
                    ),
                  )
                : Text(
                    'For outdoor walks and runs: measures real distance with GPS and ignores anything faster '
                    'than running, so a ride home never counts.',
                    style: text.bodySmall,
                  ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: walking ? 'Stop walk' : 'Start GPS walk',
            icon: walking ? Icons.stop_rounded : Icons.play_arrow_rounded,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

class _Live extends StatelessWidget {
  const _Live({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: text.titleLarge),
        Text(label, style: text.bodySmall),
      ],
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
                Text('Use location for accuracy', style: text.titleSmall),
                Text(
                  !on
                      ? 'Off: phone sensor only, best for battery'
                      : tracking
                      ? 'On: sensor + GPS combined right now'
                      : 'On: GPS joins in while the app is open',
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
