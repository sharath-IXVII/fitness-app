import '../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../profile/profile_providers.dart';
import 'domain/day_block.dart';
import 'myday_providers.dart';
import 'widgets/block_editor_sheet.dart';

/// Phase 3: the user's whole day as a timeline, with reminders.
class MyDayScreen extends ConsumerStatefulWidget {
  const MyDayScreen({super.key});

  @override
  ConsumerState<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends ConsumerState<MyDayScreen> {
  int _weekday = DateTime.now().weekday;
  late final Timer _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  bool get _isToday => _weekday == DateTime.now().weekday;

  void _edit(DayBlock block, {bool isNew = false}) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlockEditorSheet(block: block, isNew: isNew),
    );
  }

  Future<void> _pickTemplate() async {
    final profile = ref.read(profileProvider);
    final hasPlan = ref.read(myDayProvider).isNotEmpty;
    final t = await showModalBottomSheet<RoutineTemplate>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Start from a template'), style: Theme.of(c).textTheme.titleLarge),
              if (hasPlan) ...[
                const SizedBox(height: 4),
                Text(tr('This replaces your current plan.'), style: Theme.of(c).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              for (final t in RoutineTemplate.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(t.icon, color: AppColors.primary),
                  ),
                  title: Text(t.label),
                  subtitle: Text(t.description),
                  onTap: () => Navigator.pop(c, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (t == null) return;
    await ref
        .read(myDayProvider.notifier)
        .applyTemplate(
          t,
          profile?.wakeTime ?? const TimeOfDay(hour: 6, minute: 30),
          profile?.sleepTime ?? const TimeOfDay(hour: 22, minute: 30),
        );
  }

  void _deleteWithUndo(DayBlock b) {
    final notifier = ref.read(myDayProvider.notifier);
    notifier.delete(b.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${b.name} removed'),
          action: SnackBarAction(label: tr('Undo'), onPressed: () => notifier.restore(b)),
          persist: false,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(myDayProvider);
    final blocks = blocksFor(all, _weekday);
    final done = ref.watch(doneTodayProvider);
    final remindersOn = ref.watch(myDayRemindersProvider);
    final now = TimeOfDay.now();
    final nowMinute = now.hour * 60 + now.minute;
    final next = _isToday ? currentOrNext(blocks, nowMinute) : null;
    final doneCount = _isToday ? blocks.where((b) => done.contains(b.id)).length : 0;

    return PageBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(tr('My Day'), style: text.headlineMedium)),
                      IconButton(
                        tooltip: tr('Templates'),
                        onPressed: _pickTemplate,
                        icon: Icon(Icons.auto_awesome_mosaic_outlined, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Pressable(
                        onTap: () => _edit(ref.read(myDayProvider.notifier).draft(weekday: _weekday), isNew: true),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.add_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tr('Plan your day once — we\'ll remind you at every step.'), style: text.bodyMedium),
                  const SizedBox(height: 16),
                  _WeekdayPicker(value: _weekday, onChanged: (d) => setState(() => _weekday = d)),
                  const SizedBox(height: 16),
                  if (all.isNotEmpty)
                    _Summary(
                      isToday: _isToday,
                      total: blocks.length,
                      done: doneCount,
                      next: next,
                      nowMinute: nowMinute,
                      remindersOn: remindersOn,
                      onReminders: (v) => ref.read(myDayRemindersProvider.notifier).set(v),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (all.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(child: _EmptyPlan(onTemplate: _pickTemplate)),
              )
            else if (blocks.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: GlassCard(
                    child: Text(tr('Nothing planned for this day. Tap + to add something.'), style: text.bodyMedium),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.builder(
                  itemCount: blocks.length,
                  itemBuilder: (_, i) {
                    final b = blocks[i];
                    final past = _isToday && (b.minutes > 0 ? b.endMinute : b.startMinute) <= nowMinute;
                    return _TimelineRow(
                      block: b,
                      first: i == 0,
                      last: i == blocks.length - 1,
                      isNext: next?.id == b.id,
                      running: next?.id == b.id && b.startMinute <= nowMinute,
                      past: past,
                      done: _isToday && done.contains(b.id),
                      canCheck: _isToday,
                      onToggle: () {
                        HapticFeedback.lightImpact();
                        ref.read(doneTodayProvider.notifier).toggle(b.id);
                      },
                      onTap: () => _edit(b),
                      onDelete: () => _deleteWithUndo(b),
                    ).animate(delay: (i * 25).ms).fadeIn(duration: 250.ms).moveY(begin: 6, end: 0);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    return Row(
      children: [
        for (var d = 1; d <= 7; d++)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(d),
              scale: 0.92,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: d == value ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: d == value ? AppColors.primary : AppColors.stroke),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat.E().format(DateTime(monday.year, monday.month, monday.day + d - 1)).substring(0, 1),
                      style: TextStyle(
                        fontSize: 12,
                        color: d == value ? Colors.white70 : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateTime(monday.year, monday.month, monday.day + d - 1).day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: d == value ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d == today.weekday
                            ? (d == value ? Colors.white : AppColors.primary)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.isToday,
    required this.total,
    required this.done,
    required this.next,
    required this.nowMinute,
    required this.remindersOn,
    required this.onReminders,
  });

  final bool isToday;
  final int total;
  final int done;
  final DayBlock? next;
  final int nowMinute;
  final bool remindersOn;
  final ValueChanged<bool> onReminders;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String headline;
    if (!isToday) {
      headline = '$total items planned';
    } else if (next == null) {
      headline = total == 0 ? 'Free day' : 'All done for today';
    } else if (next!.startMinute <= nowMinute) {
      headline = 'Now: ${next!.name}';
    } else {
      final mins = next!.startMinute - nowMinute;
      headline = 'Next: ${next!.name} in ${mins >= 60 ? '${mins ~/ 60} h ${mins % 60} min' : '$mins min'}';
    }
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          ProgressRing(
            progress: total == 0 || !isToday ? 0 : done / total,
            color: AppColors.primary,
            size: 52,
            stroke: 6,
            child: Text(isToday ? '$done/$total' : '$total', style: text.labelMedium),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(remindersOn ? 'Reminders on' : 'Reminders off', style: text.bodySmall),
              ],
            ),
          ),
          Switch(value: remindersOn, onChanged: onReminders, activeTrackColor: AppColors.primary),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.block,
    required this.first,
    required this.last,
    required this.isNext,
    required this.running,
    required this.past,
    required this.done,
    required this.canCheck,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final DayBlock block;
  final bool first;
  final bool last;
  final bool isNext;
  final bool running;
  final bool past;
  final bool done;
  final bool canCheck;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final time = block.time.format(context);
    final dim = past && !done;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                time,
                style: text.labelMedium?.copyWith(color: isNext ? AppColors.primary : AppColors.textSecondary),
              ),
            ),
          ),
          // Rail with a node; filled once done.
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 18, color: first ? Colors.transparent : AppColors.stroke),
                GestureDetector(
                  onTap: canCheck ? onToggle : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : AppColors.surface,
                      border: Border.all(color: done || isNext ? AppColors.primary : AppColors.stroke, width: 2),
                    ),
                    child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                  ),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : AppColors.stroke)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey('block-${block.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => onDelete(),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                ),
                child: Pressable(
                  onTap: onTap,
                  scale: 0.98,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: dim ? 0.55 : 1,
                    child: GlassCard(
                      radius: 18,
                      glow: isNext ? AppColors.primary : null,
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isNext ? AppColors.primary : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(block.kind.icon, size: 20, color: isNext ? Colors.white : AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  block.name,
                                  style: text.titleSmall?.copyWith(
                                    decoration: done ? TextDecoration.lineThrough : null,
                                    decorationColor: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  [
                                    if (block.minutes > 0) '${block.minutes} min',
                                    if (block.remind)
                                      block.leadMinutes > 0 ? 'remind ${block.leadMinutes} min before' : 'reminder on',
                                  ].join(' · ').ifEmpty('No reminder'),
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (isNext)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                running ? 'Now' : 'Next',
                                style: text.labelSmall?.copyWith(color: AppColors.primary),
                              ),
                            )
                          else if (block.remind)
                            Icon(Icons.notifications_none_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.onTemplate});

  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(Icons.view_timeline_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 14),
          Text(tr('Plan your day'), style: text.titleLarge),
          const SizedBox(height: 6),
          Text(tr('Pick a template, then adjust the times. You\'ll get a reminder for each item.'),
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          GradientButton(label: tr('Choose a template'), onPressed: onTemplate),
        ],
      ),
    );
  }
}
