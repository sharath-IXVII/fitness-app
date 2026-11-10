import '../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../workout/domain/routine.dart';
import '../workout/routine_providers.dart';
import '../workout/workout_screen.dart';
import '../health/widgets/guide_card.dart';
import 'alarm_providers.dart';
import 'sleep_screens.dart';
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

  void _deleteWithUndo(WorkoutAlarm a) {
    final notifier = ref.read(alarmsProvider.notifier);
    notifier.delete(a.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('Alarm deleted')),
          action: SnackBarAction(label: tr('Undo'), onPressed: () => notifier.restore(a)),
          persist: false,
        ),
      );
  }

  void _onMenu(WorkoutAlarm a, _CardAction action) {
    final notifier = ref.read(alarmsProvider.notifier);
    switch (action) {
      case _CardAction.skip:
        notifier.skipNext(a.id);
      case _CardAction.unskip:
        notifier.skipNext(a.id, skip: false);
      case _CardAction.duplicate:
        notifier.duplicate(a);
      case _CardAction.delete:
        _deleteWithUndo(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final alarms = ref.watch(alarmsProvider);
    final routines = ref.watch(routinesProvider);

    return PageBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Expanded(child: Text(tr('Alarms'), style: text.headlineMedium)),
                Pressable(
                  onTap: () => _edit(ref.read(alarmsProvider.notifier).draft(), isNew: true),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('Each alarm keeps ringing until you finish its workout or brain game.'), style: text.bodyMedium),
            const SizedBox(height: 14),
            GuideCard(
              id: 'alarm',
              title: tr('How your alarm works'),
              steps: [
                'Tap + to add an alarm. Set the time, the days and what you must do to switch it off.',
                'Turn on Strict mode to make it impossible to cheat: full volume, no snooze, and the phone stays on the alarm until your workout is done.',
                'If you stop moving during the workout, the alarm rings again after a minute.',
                'Emergency? Restart your phone to leave Strict mode.',
              ],
            ),
            _NextUpBanner(next: ref.watch(nextAlarmProvider)),
            const SizedBox(height: 16),
            if (!_permissionsOk) ...[_PermissionBanner(onFixed: _checkPermissions), const SizedBox(height: 14)],
            if (alarms.isEmpty)
              _EmptyAlarms(onAdd: () => _edit(ref.read(alarmsProvider.notifier).draft(), isNew: true))
            else
              for (final (i, a) in alarms.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey('alarm-${a.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 28),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    ),
                    onDismissed: (_) => _deleteWithUndo(a),
                    child: _AlarmCard(
                      alarm: a,
                      routine: routineById(routines, a.routineId),
                      onTap: () => _edit(a),
                      onToggle: (v) => ref.read(alarmsProvider.notifier).toggle(a.id, v),
                      onMenu: (action) => _onMenu(a, action),
                    ),
                  ).animate(delay: (i * 50).ms).fadeIn(duration: 350.ms).slideY(begin: 0.08),
                ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(tr('Routines'), style: text.titleLarge)),
                TextButton.icon(
                  onPressed: () => context.push(Routes.routineEditor),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr('Custom')),
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

enum _CardAction { skip, unskip, duplicate, delete }

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.routine,
    required this.onTap,
    required this.onToggle,
    required this.onMenu,
  });

  final WorkoutAlarm alarm;
  final Routine routine;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final ValueChanged<_CardAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final on = alarm.enabled;
    final now = DateTime.now();
    final skipping = alarm.isSkipping(now);
    final time = alarm.time.format(context);
    final parts = time.split(' ');
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: GlassCard(
        glow: on ? AppColors.primary : null,
        padding: const EdgeInsets.fromLTRB(20, 14, 4, 14),
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
                        Text(parts.first, style: text.displaySmall?.copyWith(fontSize: 42)),
                        if (parts.length > 1) ...[
                          const SizedBox(width: 4),
                          Text(parts[1], style: text.titleMedium?.copyWith(color: AppColors.textSecondary)),
                        ],
                        if (alarm.isSleep) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.bedtime_rounded, size: 18, color: AppColors.primary),
                        ] else if (alarm.strict) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.amber),
                        ] else if (alarm.hardMode) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.local_fire_department_rounded, size: 18, color: AppColors.amber),
                        ],
                      ],
                    ),
                    Text('${alarm.label} · ${alarm.daysLabel}', style: text.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (alarm.isSleep)
                          _Tag(icon: Icons.nightlight_round, label: sleepWindowLabel(alarm))
                        else if (alarm.challenge.isGame)
                          _Tag(icon: alarm.challenge.icon, label: '${alarm.challenge.label} · ${alarm.level.label}')
                        else
                          _Tag(icon: Icons.fitness_center_rounded, label: '${routine.name} routine'),
                        if (alarm.strict)
                          _Tag(icon: Icons.lock_outline_rounded, label: alarm.isSleep ? 'Blocks other apps' : 'Strict'),
                        _Tag(icon: Icons.music_note_rounded, label: alarm.sound.label),
                        if (skipping && on)
                          _Tag(
                            icon: Icons.redo_rounded,
                            label: 'Skipping ${DateFormat.E().format(alarm.skipDate!)}',
                            color: AppColors.amber,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Switch(value: on, onChanged: onToggle, activeTrackColor: AppColors.primary),
                PopupMenuButton<_CardAction>(
                  icon: Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    if (on && alarm.repeats)
                      skipping
                          ? const PopupMenuItem(value: _CardAction.unskip, child: Text("Don't skip"))
                          : PopupMenuItem(value: _CardAction.skip, child: Text(tr('Skip next'))),
                    PopupMenuItem(value: _CardAction.duplicate, child: Text(tr('Duplicate'))),
                    PopupMenuItem(
                      value: _CardAction.delete,
                      child: Text(tr('Delete'), style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// "Next alarm in 7 h 12 min" hero with a live countdown.
class _NextUpBanner extends StatefulWidget {
  const _NextUpBanner({required this.next});

  final (WorkoutAlarm, DateTime)? next;

  @override
  State<_NextUpBanner> createState() => _NextUpBannerState();
}

class _NextUpBannerState extends State<_NextUpBanner> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = widget.next;
    final String headline, sub;
    if (next == null) {
      headline = 'No alarm set';
      sub = 'Add one to start your morning streak';
    } else {
      final d = next.$2.difference(DateTime.now());
      headline = d.inDays >= 1 ? 'In ${d.inDays} d ${d.inHours % 24} h' : 'In ${d.inHours} h ${d.inMinutes % 60} min';
      sub = '${next.$1.label} · ${DateFormat('EEE, h:mm a').format(next.$2)}';
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(Icons.alarm_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Next alarm'), style: text.labelMedium?.copyWith(color: AppColors.primary)),
                Text(headline, style: text.titleLarge),
                Text(sub, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
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
                    Flexible(
                      child: Text(routine.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (!routine.builtIn) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tr('Custom'), style: text.labelSmall?.copyWith(color: AppColors.textPrimary)),
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
              icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            ),
          TextButton(onPressed: onTry, child: Text(tr('Try'))),
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
          Icon(Icons.notifications_active_outlined, color: AppColors.steps),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr('Allow notifications, exact alarms and camera so alarms ring on time.'), style: text.bodySmall),
          ),
          TextButton(
            onPressed: () async {
              await AppPermissions.requestAll();
              onFixed();
            },
            child: Text(tr('Allow')),
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
          Icon(Icons.alarm_add_rounded, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(tr('No alarms yet'), style: text.titleMedium),
          const SizedBox(height: 4),
          Text(tr('Set one and wake up moving.'), style: text.bodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onAdd, child: Text(tr('Add alarm'))),
        ],
      ),
    );
  }
}
