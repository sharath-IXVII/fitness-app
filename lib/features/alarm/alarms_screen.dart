import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../workout/domain/routine.dart';
import '../workout/routine_providers.dart';
import '../workout/workout_screen.dart';
import 'alarm_providers.dart';
import 'app_permissions.dart';
import 'domain/workout_alarm.dart';
import 'widgets/alarm_editor_sheet.dart';

class AlarmsScreen extends ConsumerStatefulWidget {
  const AlarmsScreen({super.key});

  @override
  ConsumerState<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends ConsumerState<AlarmsScreen> with WidgetsBindingObserver {
  bool _permissionsOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when returning from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final ok = await AppPermissions.allGranted();
    if (mounted) setState(() => _permissionsOk = ok);
  }

  void _edit(WorkoutAlarm alarm, {bool isNew = false}) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlarmEditorSheet(alarm: alarm, isNew: isNew),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final alarms = ref.watch(alarmsProvider);
    final routines = ref.watch(routinesProvider);

    return AuroraBackground(
      intensity: 0.07,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          children: [
            Row(
              children: [
                Expanded(child: Text('Alarms', style: text.headlineMedium)),
                Pressable(
                  onTap: () => _edit(ref.read(alarmsProvider.notifier).draft(), isNew: true),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.softShadow(AppColors.primary),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Each alarm keeps ringing until the camera sees your workout.', style: text.bodyMedium),
            const SizedBox(height: 20),
            if (!_permissionsOk) ...[_PermissionBanner(onFixed: _checkPermissions), const SizedBox(height: 14)],
            if (alarms.isEmpty)
              _EmptyAlarms(onAdd: () => _edit(ref.read(alarmsProvider.notifier).draft(), isNew: true))
            else
              for (final (i, a) in alarms.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AlarmCard(
                    alarm: a,
                    routine: routineById(routines, a.routineId),
                    onTap: () => _edit(a),
                    onToggle: (v) => ref.read(alarmsProvider.notifier).toggle(a.id, v),
                  ).animate(delay: (i * 50).ms).fadeIn(duration: 350.ms).slideY(begin: 0.08),
                ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text('Routines', style: text.titleLarge)),
                TextButton.icon(
                  onPressed: () => context.push(Routes.routineEditor),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Custom'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final r in routines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RoutineCard(
                  routine: r,
                  onTry: () => context.push(Routes.workout, extra: WorkoutArgs(routineId: r.id)),
                  onEdit: r.builtIn ? null : () => context.push(Routes.routineEditor, extra: r),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.alarm, required this.routine, required this.onTap, required this.onToggle});

  final WorkoutAlarm alarm;
  final Routine routine;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final on = alarm.enabled;
    final time = alarm.time.format(context);
    final parts = time.split(' ');
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: GlassCard(
        glow: on ? AppColors.primary : null,
        padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
        child: Row(
          children: [
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: on ? 1 : 0.45,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(parts.first, style: text.displaySmall?.copyWith(fontSize: 40)),
                        if (parts.length > 1) ...[
                          const SizedBox(width: 4),
                          Text(parts[1], style: text.titleMedium?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${alarm.label} · ${alarm.daysLabel}', style: text.bodyMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('${routine.name} routine', style: text.labelMedium?.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Switch(value: on, onChanged: onToggle, activeTrackColor: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.onTry, this.onEdit});

  final Routine routine;
  final VoidCallback onTry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(routine.name, style: text.titleMedium),
                    if (!routine.builtIn) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Custom', style: text.labelSmall?.copyWith(color: AppColors.textPrimary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(routine.summary, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            ),
          TextButton(onPressed: onTry, child: const Text('Try')),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onFixed});

  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      glow: AppColors.steps,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.steps),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Allow notifications, exact alarms and camera so alarms ring on time.', style: text.bodySmall),
          ),
          TextButton(
            onPressed: () async {
              await AppPermissions.requestAll();
              onFixed();
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlarms extends StatelessWidget {
  const _EmptyAlarms({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.alarm_add_rounded, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('No alarms yet', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('Set one and wake up moving.', style: text.bodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onAdd, child: const Text('Add alarm')),
        ],
      ),
    );
  }
}
