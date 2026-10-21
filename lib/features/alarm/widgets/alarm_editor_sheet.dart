import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../workout/routine_providers.dart';
import '../alarm_providers.dart';
import '../app_permissions.dart';
import '../domain/workout_alarm.dart';

class AlarmEditorSheet extends ConsumerStatefulWidget {
  const AlarmEditorSheet({super.key, required this.alarm, this.isNew = false});

  final WorkoutAlarm alarm;
  final bool isNew;

  @override
  ConsumerState<AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends ConsumerState<AlarmEditorSheet> {
  late int _hour = widget.alarm.time.hour;
  late int _minute = widget.alarm.time.minute;
  late Set<int> _days = {...widget.alarm.days};
  late String _routineId = widget.alarm.routineId;
  late final _label = TextEditingController(text: widget.alarm.label);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(alarmsProvider.notifier);
    await notifier.save(
      widget.alarm.copyWith(
        time: TimeOfDay(hour: _hour, minute: _minute),
        days: _days,
        routineId: _routineId,
        label: _label.text.trim().isEmpty ? 'Workout alarm' : _label.text.trim(),
        enabled: true,
      ),
    );
    if (!await AppPermissions.allGranted()) await AppPermissions.requestAll();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final at = ref.read(alarmsProvider).firstWhere((a) => a.id == widget.alarm.id).nextOccurrence(DateTime.now());
    final diff = at.difference(DateTime.now());
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Alarm set for ${diff.inHours} h ${diff.inMinutes % 60} min from now')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final routines = ref.watch(routinesProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(widget.isNew ? 'New alarm' : 'Edit alarm', style: text.titleLarge)),
                  if (!widget.isNew)
                    IconButton(
                      onPressed: () {
                        ref.read(alarmsProvider.notifier).delete(widget.alarm.id);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 170,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Wheel(count: 24, value: _hour, onChanged: (v) => setState(() => _hour = v)),
                    Text(':', style: text.displaySmall),
                    _Wheel(count: 60, value: _minute, onChanged: (v) => setState(() => _minute = v)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Repeat', style: text.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (i, d) in ['M', 'T', 'W', 'T', 'F', 'S', 'S'].indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Pressable(
                          onTap: () => setState(() {
                            _days = {..._days};
                            _days.contains(i + 1) ? _days.remove(i + 1) : _days.add(i + 1);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _days.contains(i + 1) ? AppColors.primary : AppColors.surfaceHigh,
                            ),
                            child: Text(
                              d,
                              style: text.titleSmall?.copyWith(
                                color: _days.contains(i + 1) ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _days.isEmpty
                    ? 'Rings once'
                    : WorkoutAlarm(id: 0, time: TimeOfDay.now(), routineId: '', days: _days).daysLabel,
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('Routine to stop it', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in routines)
                    ChoiceChip(
                      label: Text(r.name),
                      selected: _routineId == r.id,
                      onSelected: (_) => setState(() => _routineId = r.id),
                      selectedColor: AppColors.primary.withValues(alpha: 0.14),
                      side: BorderSide(color: _routineId == r.id ? AppColors.primary : AppColors.stroke),
                      labelStyle: TextStyle(
                        color: _routineId == r.id ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(routineById(routines, _routineId).summary, style: text.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: _label,
                decoration: const InputDecoration(hintText: 'Label'),
              ),
              const SizedBox(height: 20),
              GradientButton(label: 'Save alarm', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({required this.count, required this.value, required this.onChanged});

  final int count;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final _controller = FixedExtentScrollController(initialItem: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall;
    return SizedBox(
      width: 96,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 56,
        perspective: 0.004,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.3,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          widget.onChanged(i % widget.count);
        },
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < widget.count; i++) Center(child: Text(i.toString().padLeft(2, '0'), style: style)),
          ],
        ),
      ),
    );
  }
}
