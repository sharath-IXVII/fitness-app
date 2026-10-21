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
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/sunrise_scene.dart';
import '../workout/routine_providers.dart';
import '../workout/workout_screen.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';

/// Full-screen view while an alarm rings: an animated sunrise over rolling
/// hills. There is no dismiss button — the way out is the workout. Snooze
/// and a deliberately awkward emergency stop exist unless hard mode is on.
class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key, required this.info});

  final RingInfo info;

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  static const _quotes = [
    'Your future self is already thanking you.',
    'Two minutes of effort beats twenty of snoozing.',
    'Champions are made before breakfast.',
    'Move first. Coffee second.',
    'Small reps, every morning, add up to a new you.',
  ];
  late final String _quote = _quotes[DateTime.now().day % _quotes.length];

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
    await AlarmScheduler.silence(widget.info);
    await ref.read(alarmsProvider.notifier).handled(widget.info.alarmId);
    if (mounted) context.go(Routes.home);
  }

  Future<void> _snooze() async {
    HapticFeedback.mediumImpact();
    final info = widget.info;
    await AlarmScheduler.snooze(info);
    if (!mounted) return;
    final until = DateTime.now().add(Duration(minutes: info.snoozeMinutes));
    final messenger = ScaffoldMessenger.of(context);
    context.go(Routes.home);
    messenger.showSnackBar(
      SnackBar(content: Text('Snoozed until ${DateFormat.jm().format(until)} · ${info.snoozesLeft - 1} left')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = widget.info;
    final routine = routineById(ref.watch(routinesProvider), info.routineId);
    final canSnooze = !info.hardMode && info.snoozesLeft > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SunriseScene(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(_now).toUpperCase(),
                      style: text.labelMedium?.copyWith(letterSpacing: 1.8, color: AppColors.textSecondary),
                    ).animate().fadeIn(duration: 600.ms),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.jm().format(_now),
                      style: text.displayLarge?.copyWith(fontSize: 72, color: AppColors.textPrimary, height: 1.05),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.15, curve: Curves.easeOutCubic),
                    const SizedBox(height: 10),
                    Text(info.label, style: text.titleLarge).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: 4),
                    Text(
                      _quote,
                      style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ).animate(delay: 500.ms).fadeIn(),
                    const Spacer(),
                    GlassCard(
                      blur: true,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('TO TURN IT OFF', style: text.labelSmall?.copyWith(letterSpacing: 1.3)),
                              const Spacer(),
                              if (info.hardMode)
                                Row(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.danger),
                                    const SizedBox(width: 4),
                                    Text('Hard mode', style: text.labelSmall?.copyWith(color: AppColors.danger)),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final (i, s) in routine.steps.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(s.exercise.icon, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(s.exercise.label, style: text.titleSmall)),
                                  Text(s.exercise.formatTarget(s.target), style: text.titleSmall),
                                ],
                              ),
                            ).animate(delay: (700 + i * 90).ms).fadeIn().slideX(begin: 0.06),
                        ],
                      ),
                    ).animate(delay: 500.ms).fadeIn(duration: 500.ms).slideY(begin: 0.12),
                    const SizedBox(height: 16),
                    GradientButton(
                          label: 'Start workout',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => context.go(
                            Routes.workout,
                            extra: WorkoutArgs(routineId: routine.id, ring: info),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(end: 1.03, duration: 900.ms, curve: Curves.easeInOut),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (canSnooze)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _snooze,
                              icon: const Icon(Icons.snooze_rounded, size: 18),
                              label: Text('Snooze ${info.snoozeMinutes} min · ${info.snoozesLeft} left'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: AppColors.surface.withValues(alpha: 0.7),
                                side: const BorderSide(color: AppColors.stroke),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                            ),
                          ),
                        if (canSnooze && !info.hardMode) const SizedBox(width: 10),
                        if (!info.hardMode)
                          TextButton(
                            onPressed: _emergencyStop,
                            child: Text('Emergency stop', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
