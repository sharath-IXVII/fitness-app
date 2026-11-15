import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../myday/myday_providers.dart';
import '../report/report_providers.dart';
import '../streaks/streak_reminder.dart';
import '../training/workout_reminder.dart';
import '../water/water_providers.dart';

/// Every reminder the app sends, in one place: switch each on or off and,
/// where it has a time, tap the time to change it.
class RemindersCard extends ConsumerWidget {
  const RemindersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakReminderProvider);
    final report = ref.watch(reportSettingsProvider);
    final workout = ref.watch(workoutReminderProvider);
    final water = ref.watch(waterSettingsProvider);
    final myDay = ref.watch(myDayRemindersProvider);

    TimeOfDay at(int minute) => TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    Future<int?> pick(int minute) async {
      final t = await showTimePicker(context: context, initialTime: at(minute));
      return t == null ? null : t.hour * 60 + t.minute;
    }

    final every = water.everyMinutes % 60 == 0
        ? '${water.everyMinutes ~/ 60} h'
        : '${(water.everyMinutes / 60).toStringAsFixed(1)} h';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          _Row(
            icon: Icons.local_fire_department_rounded,
            title: tr('Streak reminder'),
            detail: tr('Only when today still needs goals'),
            time: at(streak.minute).format(context),
            on: streak.enabled,
            onToggle: (v) => ref.read(streakReminderProvider.notifier).set(enabled: v),
            onTime: () async {
              final m = await pick(streak.minute);
              if (m != null) await ref.read(streakReminderProvider.notifier).set(minute: m);
            },
          ),
          _Row(
            icon: Icons.insights_rounded,
            title: tr('Daily report'),
            detail: tr('Your day, every evening'),
            time: at(report.minute).format(context),
            on: report.enabled,
            onToggle: (v) => ref.read(reportSettingsProvider.notifier).set(enabled: v),
            onTime: () async {
              final m = await pick(report.minute);
              if (m != null) await ref.read(reportSettingsProvider.notifier).set(minute: m);
            },
          ),
          _Row(
            icon: Icons.fitness_center_rounded,
            title: tr('Workout reminder'),
            detail: tr("Quiet once today's workout is done"),
            time: workout.time.format(context),
            on: workout.enabled,
            onToggle: (v) => ref.read(workoutReminderProvider.notifier).set(enabled: v),
            onTime: () async {
              final m = await pick(workout.minute);
              if (m != null) await ref.read(workoutReminderProvider.notifier).set(time: at(m));
            },
          ),
          _Row(
            icon: Icons.water_drop_rounded,
            title: tr('Water reminders'),
            detail: '${tr('Every')} $every, ${tr('from wake-up to bedtime')}',
            on: water.reminders,
            onToggle: (v) => ref.read(waterSettingsProvider.notifier).set(reminders: v),
          ),
          _Row(
            icon: Icons.view_timeline_rounded,
            title: tr('My Day reminders'),
            detail: tr('For the items in your routine'),
            on: myDay,
            onToggle: (v) => ref.read(myDayRemindersProvider.notifier).set(v),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.detail,
    required this.on,
    required this.onToggle,
    this.time,
    this.onTime,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool on;
  final ValueChanged<bool> onToggle;
  final String? time;
  final VoidCallback? onTime;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: on ? AppColors.primary : AppColors.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(detail, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (time != null)
            TextButton(
              onPressed: on ? onTime : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(time!),
            ),
          Semantics(
            label: title,
            child: Switch(value: on, onChanged: onToggle),
          ),
        ],
      ),
    );
  }
}
