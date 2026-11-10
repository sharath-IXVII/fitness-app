import '../../core/i18n/i18n.dart';
import 'dart:async';

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
import 'sleep_mode.dart';
import 'sleep_screens.dart';
import 'strict_mode.dart';

/// Full-screen view while an alarm rings. There is no dismiss button — the
/// A normal alarm has Snooze and Stop like any phone alarm, with the
/// workout or game offered. With "No snooze" or Strict mode the workout or
/// game is the only way out (in Strict mode, restarting the phone in an
/// emergency).
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
    if (!widget.info.isSleep) {
      // A wake-up alarm ends any Sleep mode still in force.
      unawaited(SleepMode.release(ref.read(sharedPrefsProvider)));
      if (widget.info.strict) StrictMode.engage(ref.read(sharedPrefsProvider), widget.info);
    }
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

  /// A normal alarm stops like any phone alarm.
  Future<void> _stop() async {
    HapticFeedback.mediumImpact();
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
    if (info.isSleep) return SleepRing(info: info);
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
                          Text(
                            info.hardMode ? 'To turn it off' : 'Start your day with',
                            style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          if (info.strict)
                            _Tag(icon: Icons.lock_outline_rounded, label: tr('Strict mode'))
                          else if (info.hardMode)
                            _Tag(icon: Icons.local_fire_department_outlined, label: tr('No snooze')),
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
                      if (info.strict) ...[
                        const SizedBox(height: 8),
                        Text(tr('Emergency? Restarting your phone ends strict mode and stops this alarm.'),
                          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
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
                            side: BorderSide(color: AppColors.stroke),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    if (canSnooze) const SizedBox(width: 8),
                    if (!info.hardMode)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _stop,
                          icon: const Icon(Icons.alarm_off_rounded, size: 18),
                          label: Text(tr('Stop')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            side: BorderSide(color: AppColors.stroke),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
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
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primarySoft),
              )
              .animate(onPlay: (c) => c.repeat(), delay: (i * 1000).ms)
              .scaleXY(begin: 1, end: 1.65, duration: 2000.ms, curve: Curves.easeOut)
              .fadeOut(duration: 2000.ms, curve: Curves.easeIn),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
          child: const Icon(Icons.alarm_rounded, size: 34, color: Colors.white),
        ),
      ],
    ),
  );
}
