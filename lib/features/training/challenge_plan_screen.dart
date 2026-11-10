import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import 'domain/plans.dart';
import 'training_providers.dart';
import 'widgets/move_widgets.dart';

/// A 30-day challenge: pick a level, then work through the days in order.
class ChallengePlanScreen extends ConsumerStatefulWidget {
  const ChallengePlanScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<ChallengePlanScreen> createState() => _ChallengePlanScreenState();
}

class _ChallengePlanScreenState extends ConsumerState<ChallengePlanScreen> {
  Level _level = Level.beginner;

  Challenge get c => widget.challenge;

  static const _levelNotes = {
    Level.beginner: 'New to exercise or getting back into it.',
    Level.intermediate: 'You work out now and then.',
    Level.advanced: 'You train regularly and want a push.',
  };

  void _openDay(int day, ChallengeProgress p) {
    final workout = c.workoutFor(day, p.level);
    if (workout != null) {
      context.push(Routes.trainingPreview, extra: workout);
      return;
    }
    if (p.done.contains(day) || p.nextDay != day) return;
    _restDay(day);
  }

  Future<void> _restDay(int day) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Rest day')),
        content: Text(tr('Muscles grow while you rest. Take it easy today: a walk or the stretch session is perfect.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Not yet'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Mark as done'))),
        ],
      ),
    );
    if (done == true) {
      HapticFeedback.mediumImpact();
      await ref.read(trainingProvider.notifier).completeDay(c.id, day);
    }
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Restart challenge?')),
        content: Text(tr('Your progress in this challenge will be cleared.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Restart'))),
        ],
      ),
    );
    if (ok == true) await ref.read(trainingProvider.notifier).quitChallenge(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = ref.watch(trainingProvider).challenges[c.id];

    return Scaffold(
      appBar: AppBar(
        title: Text(c.title),
        actions: [
          if (p != null)
            IconButton(
              tooltip: tr('Restart challenge'),
              onPressed: _restart,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
        ],
      ),
      body: PageBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  HeroWorkoutCard(
                    demo: c.demo,
                    eyebrow: p?.level.label ?? '30 days',
                    title: c.title,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.blurb),
                        if (p != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${p.done.length} of ${Challenge.days} days done',
                            style: text.labelLarge?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          EnergyBar(value: p.fraction),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (p == null) ...[
                    Text(tr('Choose your level'), style: text.titleLarge),
                    const SizedBox(height: 10),
                    SegmentedPills(
                      options: [for (final l in Level.values) l.label],
                      index: _level.index,
                      onChanged: (i) => setState(() => _level = Level.values[i]),
                    ),
                    const SizedBox(height: 8),
                    Text(_levelNotes[_level]!, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('How it works'), style: text.titleMedium),
                          const SizedBox(height: 8),
                          for (final line in [
                            '${Challenge.days} days, a little harder each day.',
                            'About ${c.workoutFor(1, _level)!.minutes}–${c.workoutFor(29, _level)!.minutes} minutes a day.',
                            'A rest day every fourth day.',
                            'Do the days in order; missed one? Just pick up where you left off.',
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(line, style: text.bodyMedium)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else
                    _DayGrid(progress: p, onTap: (d) => _openDay(d, p)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: _cta(p)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cta(ChallengeProgress? p) {
    if (p == null) {
      return GradientButton(
        label: tr('Start challenge'),
        icon: Icons.flag_rounded,
        onPressed: () {
          HapticFeedback.mediumImpact();
          ref.read(trainingProvider.notifier).startChallenge(c.id, _level);
        },
      );
    }
    final next = p.nextDay;
    if (next == null) {
      return GradientButton(
        label: tr('Challenge complete! Start again'),
        icon: Icons.emoji_events_rounded,
        onPressed: _restart,
      );
    }
    return GradientButton(
      label: Challenge.isRestDay(next) ? 'Day $next · Rest day' : 'Start day $next',
      icon: Challenge.isRestDay(next) ? Icons.bedtime_rounded : Icons.play_arrow_rounded,
      onPressed: () => _openDay(next, p),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.progress, required this.onTap});

  final ChallengeProgress progress;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = progress.nextDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var week = 0; week * 7 < Challenge.days; week++) ...[
          Text('Week ${week + 1}', style: text.titleSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: week * 7 + i < Challenge.days
                      ? _DayCell(
                          day: week * 7 + i + 1,
                          done: progress.done.contains(week * 7 + i + 1),
                          isNext: next == week * 7 + i + 1,
                          onTap: onTap,
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.done, required this.isNext, required this.onTap});

  final int day;
  final bool done;
  final bool isNext;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rest = Challenge.isRestDay(day);
    final open = done || isNext;
    return Semantics(
      button: open,
      label:
          'Day $day${rest ? ', rest day' : ''}${done
              ? ', done'
              : isNext
              ? ', next'
              : ''}',
      child: GestureDetector(
        onTap: open ? () => onTap(day) : null,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done ? AppColors.brandGradient : null,
              color: done ? null : (isNext ? AppColors.surface : AppColors.surfaceHigh),
              border: isNext ? Border.all(color: AppColors.energy, width: 2.5) : null,
              boxShadow: isNext ? AppColors.softShadow(AppColors.energy) : null,
            ),
            child: done
                ? Icon(rest ? Icons.bedtime_rounded : Icons.check_rounded, color: Colors.white, size: 20)
                : rest
                ? Icon(Icons.bedtime_outlined, size: 18, color: isNext ? AppColors.energy : AppColors.textMuted)
                : Text(
                    '$day',
                    style: text.labelLarge?.copyWith(
                      color: isNext ? AppColors.textPrimary : AppColors.textMuted,
                      fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
