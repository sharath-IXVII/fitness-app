import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../workout/routine_providers.dart';
import '../workout/workout_screen.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';

/// Full-screen view while an alarm rings. There is no dismiss button: the
/// way out is the workout. A deliberately awkward emergency stop exists for
/// genuine emergencies.
class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key, required this.info});

  final RingInfo info;

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _emergencyStop() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _EmergencyDialog());
    if (ok != true || !mounted) return;
    await AlarmScheduler.stop(AlarmScheduler.watchdogId);
    await ref.read(alarmsProvider.notifier).handled(widget.info.alarmId);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final routine = routineById(ref.watch(routinesProvider), widget.info.routineId);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AuroraBackground(
          colors: const [AppColors.primary, AppColors.gold, AppColors.accent],
          intensity: 0.16,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM').format(_now).toUpperCase(),
                    style: text.labelMedium?.copyWith(letterSpacing: 1.6, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat.jm().format(_now),
                    style: text.displayLarge?.copyWith(fontSize: 68, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  const _PulsingBell(),
                  const SizedBox(height: 28),
                  Text(widget.info.label, style: text.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'The alarm stops when your workout is done.',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final s in routine.steps)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(s.exercise.icon, size: 20, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(child: Text(s.exercise.label, style: text.titleSmall)),
                                Text(s.exercise.formatTarget(s.target), style: text.titleSmall),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Start workout',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context.go(
                      Routes.workout,
                      extra: WorkoutArgs(routineId: routine.id, ring: widget.info),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.03, duration: 900.ms),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _emergencyStop,
                    child: Text('Emergency stop', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingBell extends StatelessWidget {
  const _PulsingBell();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.12)),
                )
                .animate(onPlay: (c) => c.repeat(), delay: (i * 600).ms)
                .scaleXY(begin: 0.9, end: 1.7, duration: 1800.ms, curve: Curves.easeOut)
                .fadeOut(duration: 1800.ms),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: AppColors.softShadow(AppColors.primary),
            ),
            child: const Icon(Icons.alarm_rounded, size: 52, color: Colors.white),
          ).animate(onPlay: (c) => c.repeat()).shake(hz: 5, rotation: 0.08, duration: 700.ms).then(delay: 500.ms),
        ],
      ),
    );
  }
}

/// Hold for three seconds, then solve a sum. Annoying on purpose.
class _EmergencyDialog extends StatefulWidget {
  const _EmergencyDialog();

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        setState(() => _unlocked = true);
      }
    });
  final _answer = TextEditingController();
  final _rng = math.Random();
  late final int _a = 12 + _rng.nextInt(30), _b = 3 + _rng.nextInt(7);
  bool _unlocked = false;
  bool _wrong = false;

  @override
  void dispose() {
    _hold.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Emergency stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's workout won't count and your streak may break.", style: text.bodyMedium),
          const SizedBox(height: 20),
          if (!_unlocked)
            GestureDetector(
              onTapDown: (_) => _hold.forward(),
              onTapUp: (_) => _hold.reverse(),
              onTapCancel: () => _hold.reverse(),
              child: AnimatedBuilder(
                animation: _hold,
                builder: (_, _) => Container(
                  height: 54,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppColors.surfaceHigh),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: _hold.value,
                        child: Container(color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      Center(child: Text('Press and hold for 3 seconds', style: text.titleSmall)),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Text('What is $_a × $_b?', style: text.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _answer,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Answer', errorText: _wrong ? 'Not quite' : null),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("I'll work out")),
        if (_unlocked)
          TextButton(
            onPressed: () {
              if (int.tryParse(_answer.text.trim()) == _a * _b) {
                Navigator.pop(context, true);
              } else {
                setState(() => _wrong = true);
              }
            },
            child: const Text('Stop alarm', style: TextStyle(color: AppColors.danger)),
          ),
      ],
    );
  }
}
