import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reminders.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/day_block.dart';
import '../myday_providers.dart';

class BlockEditorSheet extends ConsumerStatefulWidget {
  const BlockEditorSheet({super.key, required this.block, this.isNew = false});

  final DayBlock block;
  final bool isNew;

  @override
  ConsumerState<BlockEditorSheet> createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends ConsumerState<BlockEditorSheet> {
  late DayBlock _b = widget.block;
  late final _title = TextEditingController(text: widget.block.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _set(DayBlock b) => setState(() => _b = b);

  Future<void> _save() async {
    if (_b.remind) await Reminders.requestPermission();
    await ref.read(myDayProvider.notifier).save(_b.copyWith(title: _title.text.trim()));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(widget.isNew ? 'Add to your day' : 'Edit item', style: text.titleLarge)),
                  if (!widget.isNew)
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () {
                        ref.read(myDayProvider.notifier).delete(widget.block.id);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormSection(
                      title: 'What',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final k in BlockKind.values)
                            ChoicePill(
                              label: k.label,
                              selected: _b.kind == k,
                              onTap: () => _set(_b.copyWith(kind: k)),
                            ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: 'Name (optional)',
                      child: TextField(
                        controller: _title,
                        decoration: InputDecoration(hintText: _b.kind.label),
                      ),
                    ),
                    FormSection(
                      title: 'When',
                      child: SizedBox(
                        height: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TimeWheel(
                              count: 24,
                              value: _b.time.hour,
                              onChanged: (v) => _set(
                                _b.copyWith(
                                  time: TimeOfDay(hour: v, minute: _b.time.minute),
                                ),
                              ),
                            ),
                            Text(':', style: text.displaySmall),
                            TimeWheel(
                              count: 60,
                              value: _b.time.minute,
                              onChanged: (v) => _set(
                                _b.copyWith(
                                  time: TimeOfDay(hour: _b.time.hour, minute: v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FormSection(
                      title: 'How long',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in [0, 15, 30, 45, 60, 90, 120, 240])
                            ChoicePill(
                              label: m == 0 ? 'No duration' : (m < 60 ? '$m min' : '${m / 60} h'.replaceAll('.0', '')),
                              selected: _b.minutes == m,
                              onTap: () => _set(_b.copyWith(minutes: m)),
                            ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: 'Repeat on',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final (label, days) in [
                                ('Every day', weekdaySets.all),
                                ('Weekdays', weekdaySets.weekdays),
                                ('Weekends', weekdaySets.weekend),
                              ])
                                ChoicePill(
                                  label: label,
                                  selected: _b.days.length == days.length && _b.days.containsAll(days),
                                  onTap: () => _set(_b.copyWith(days: {...days})),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (final (i, d) in ['M', 'T', 'W', 'T', 'F', 'S', 'S'].indexed)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: DayDot(
                                      label: d,
                                      selected: _b.days.contains(i + 1),
                                      onTap: () {
                                        final days = {..._b.days};
                                        days.contains(i + 1) ? days.remove(i + 1) : days.add(i + 1);
                                        if (days.isNotEmpty) _set(_b.copyWith(days: days));
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: 'Reminder',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SettingToggle(
                            icon: Icons.notifications_none_rounded,
                            title: 'Remind me',
                            subtitle: 'With Done and Snooze buttons in the notification',
                            value: _b.remind,
                            onChanged: (v) => _set(_b.copyWith(remind: v)),
                          ),
                          if (_b.remind) ...[
                            const SizedBox(height: 8),
                            SegmentedPills(
                              options: const ['On time', '5 min', '10 min', '15 min'],
                              index: const [0, 5, 10, 15].indexOf(_b.leadMinutes).clamp(0, 3),
                              onChanged: (i) => _set(_b.copyWith(leadMinutes: const [0, 5, 10, 15][i])),
                            ),
                            const SizedBox(height: 4),
                            Text('How early to remind you', style: text.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GradientButton(label: widget.isNew ? 'Add' : 'Save', icon: Icons.check_rounded, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
