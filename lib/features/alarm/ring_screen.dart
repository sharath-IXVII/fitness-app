import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../challenge/challenge_screen.dart';
import '../workout/domain/routine.dart';
import '../workout/routine_providers.dart';
import '../workout/workout_screen.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';
import 'strict_mode.dart';

/// Full-screen view while an alarm rings. There is no dismiss button — the
/// way out is the workout or brain game. Snooze and a deliberately awkward
/// emergency stop exist unless the alarm has no snooze or strict mode on.
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
    if (widget.info.strict) StrictMode.engage(ref.read(sharedPrefsProvider), widget.info);
  }

  void _start(Routine routine) {
    HapticFeedback.mediumImpact();
    final info = widget.info;
    if (info.challenge.isGame) {
      context.go(
        Routes.challenge,
        extra: ChallengeArgs(challenge: info.challenge, level: info.level, ring: info),
      );
    } else {
      context.go(
        Routes.workout,
        extra: WorkoutArgs(routineId: routine.id, ring: info),
      );
    }
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
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            child: Column(
              children: [
                const _RingingIcon(),
                const SizedBox(height: 28),
                Text(
                  DateFormat.jm().format(_now),
                  style: text.displayLarge?.copyWith(fontSize: 64, color: AppColors.textPrimary, height: 1.05),
                ),
                const SizedBox(height: 4),
                Text(DateFormat('EEEE, d MMMM').format(_now), style: text.bodyMedium),
                const SizedBox(height: 20),
                Text(info.label, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(_quote, style: text.bodyMedium, textAlign: TextAlign.center),
                const Spacer(),
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('To turn it off', style: text.labelMedium?.copyWith(color: AppColors.textSecondary)),
                          const Spacer(),
                          if (info.strict)
                            _Tag(icon: Icons.lock_outline_rounded, label: 'Strict mode')
                          else if (info.hardMode)
                            _Tag(icon: Icons.local_fire_department_outlined, label: 'No snooze'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (info.challenge.isGame)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(info.challenge.icon, size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(child: Text(info.challenge.description, style: text.titleSmall)),
                              Text(info.level.label, style: text.titleSmall),
                            ],
                          ),
                        )
                      else
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
                ).animate().fadeIn(duration: 300.ms, delay: 150.ms).moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                GradientButton(
                  label: info.challenge.isGame ? 'Start ${info.challenge.label.toLowerCase()}' : 'Start workout',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _start(routine),
                ),
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
                            foregroundColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.stroke),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    if (canSnooze) const SizedBox(width: 8),
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
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.amber),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.amber)),
    ],
  );
}

/// Alarm icon with two soft rings expanding outward — the only motion on
/// the screen, so it reads as "ringing" without being noisy.
class _RingingIcon extends StatelessWidget {
  const _RingingIcon();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 120,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < 2; i++)
          Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primarySoft),
              )
              .animate(onPlay: (c) => c.repeat(), delay: (i * 1000).ms)
              .scaleXY(begin: 1, end: 1.65, duration: 2000.ms, curve: Curves.easeOut)
              .fadeOut(duration: 2000.ms, curve: Curves.easeIn),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
          child: const Icon(Icons.alarm_rounded, size: 34, color: Colors.white),
        ),
      ],
    ),
  );
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
