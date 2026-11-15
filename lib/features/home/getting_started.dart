import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../arcs/arc_providers.dart';
import '../myday/myday_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../streaks/domain/daily_log.dart';

/// The first things worth trying, in order of effort.
enum StartStep {
  water(Icons.water_drop_rounded, 'Drink a glass of water', 'Tap +250 ml below'),
  walk(Icons.directions_walk_rounded, 'Take a short walk', '500 steps is enough to start'),
  meal(Icons.photo_camera_rounded, 'Snap a meal', 'The camera names the dish'),
  workout(Icons.fitness_center_rounded, 'Do a 5-minute workout', 'Morning warm-up is a gentle first one'),
  plan(Icons.view_timeline_rounded, 'Plan your day', 'Pick a template in My Day');

  const StartStep(this.icon, this.title, this.hint);

  final IconData icon;
  final String title;
  final String hint;
}

/// How long the list is offered to someone new.
const startDays = 14;

/// Which first steps are done, from what the app already records.
Set<StartStep> startStepsDone(Iterable<DailyLog> logs, {required bool hasPlan}) => {
  if (logs.any((l) => l.waterMl > 0)) StartStep.water,
  if (logs.any((l) => l.steps >= 500)) StartStep.walk,
  if (logs.any((l) => l.mealsLogged > 0)) StartStep.meal,
  if (logs.any((l) => l.workoutDone)) StartStep.workout,
  if (hasPlan) StartStep.plan,
};

class StartHiddenNotifier extends Notifier<bool> {
  static const key = 'start.hidden.v1';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(key) ?? false;

  Future<void> hide() async {
    state = true;
    await ref.read(sharedPrefsProvider).setBool(key, true);
  }
}

final startHiddenProvider = NotifierProvider<StartHiddenNotifier, bool>(StartHiddenNotifier.new);

/// The steps done, or null when the list should not show: hidden, finished,
/// or the person is no longer new.
final startStepsProvider = Provider<Set<StartStep>?>((ref) {
  if (ref.watch(startHiddenProvider)) return null;
  final age = daysBetween(ref.watch(firstUseProvider), ref.watch(todayProvider));
  if (age >= startDays) return null;
  final done = startStepsDone(ref.watch(dailyLogsProvider).values, hasPlan: ref.watch(myDayProvider).isNotEmpty);
  return done.length == StartStep.values.length ? null : done;
});

/// "Your first steps": a short list for someone new, ticked off by itself as
/// they use the app. It leaves when all are done, after two weeks, or on Hide.
class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({super.key});

  void _open(BuildContext context, StartStep s) => switch (s) {
    StartStep.water => context.push(Routes.water),
    StartStep.walk => context.push(Routes.steps),
    StartStep.meal => context.go(Routes.diet),
    StartStep.workout => context.go(Routes.training),
    StartStep.plan => context.go(Routes.myDay),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(startStepsProvider);
    if (done == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final total = StartStep.values.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('Your first steps'), style: text.titleMedium)),
                Text('${done.length} / $total', style: text.labelLarge?.copyWith(color: AppColors.primary)),
                TextButton(onPressed: () => ref.read(startHiddenProvider.notifier).hide(), child: Text(tr('Hide'))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: done.length / total,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceHigh,
                  color: AppColors.primary,
                ),
              ),
            ),
            for (final s in StartStep.values)
              Pressable(
                onTap: done.contains(s) ? null : () => _open(context, s),
                scale: 0.98,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 7, 8, 7),
                  child: Row(
                    children: [
                      Icon(
                        done.contains(s) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: done.contains(s) ? AppColors.primary : AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(s.title),
                              style: text.titleSmall?.copyWith(
                                color: done.contains(s) ? AppColors.textTertiary : null,
                                decoration: done.contains(s) ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (!done.contains(s))
                              Text(tr(s.hint), style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (!done.contains(s)) Icon(s.icon, color: AppColors.primary, size: 20),
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
