import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/form_controls.dart';
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
  late WorkoutAlarm _a = widget.alarm;
  late final _label = TextEditingController(text: widget.alarm.label);
  final _player = AudioPlayer();
  AlarmSound? _previewing;

  @override
  void dispose() {
    _label.dispose();
    _player.dispose().catchError((_) {});
    super.dispose();
  }

  void _update(WorkoutAlarm a) => setState(() => _a = a);

  Future<void> _preview(AlarmSound s) async {
    _update(_a.copyWith(sound: s));
    setState(() => _previewing = s);
    try {
      await _player.stop();
      await _player.setVolume(_a.volume);
      await _player.play(AssetSource('sounds/${s.file}.wav'));
    } catch (_) {
      // Preview is a nicety; ignore audio errors.
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _previewing != s) return;
    await _quiet();
    setState(() => _previewing = null);
  }

  /// Audio is only for previews; never let a player error block the editor.
  Future<void> _quiet() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _save() async {
    unawaited(_quiet());
    final notifier = ref.read(alarmsProvider.notifier);
    final saved = _a.copyWith(
      label: _label.text.trim().isEmpty ? 'Workout alarm' : _label.text.trim(),
      enabled: true,
      clearSkip: true,
    );
    await notifier.save(saved);
    if (!await AppPermissions.allGranted()) await AppPermissions.requestAll();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('Alarm set for ${_untilText(saved)} from now')));
  }

  static String _untilText(WorkoutAlarm a) {
    final d = a.nextOccurrence(DateTime.now()).difference(DateTime.now());
    if (d.inDays >= 1) return '${d.inDays} d ${d.inHours % 24} h';
    return '${d.inHours} h ${d.inMinutes % 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final routines = ref.watch(routinesProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                  Expanded(child: Text(widget.isNew ? 'New alarm' : 'Edit alarm', style: text.titleLarge)),
                  if (!widget.isNew)
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () {
                        ref.read(alarmsProvider.notifier).delete(widget.alarm.id);
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
                    SizedBox(
                      height: 170,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TimeWheel(
                            count: 24,
                            value: _a.time.hour,
                            onChanged: (v) => _update(
                              _a.copyWith(
                                time: TimeOfDay(hour: v, minute: _a.time.minute),
                              ),
                            ),
                          ),
                          Text(':', style: text.displaySmall),
                          TimeWheel(
                            count: 60,
                            value: _a.time.minute,
                            onChanged: (v) => _update(
                              _a.copyWith(
                                time: TimeOfDay(hour: _a.time.hour, minute: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          'Rings in ${_untilText(_a.copyWith(clearSkip: true))}',
                          key: ValueKey(_untilText(_a)),
                          style: text.labelLarge?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ),
                    FormSection(
                      title: 'Repeat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (label, days) in [
                                ('Once', <int>{}),
                                ('Weekdays', {1, 2, 3, 4, 5}),
                                ('Weekends', {6, 7}),
                                ('Every day', {1, 2, 3, 4, 5, 6, 7}),
                              ])
                                ChoicePill(
                                  label: label,
                                  selected: _a.days.length == days.length && _a.days.containsAll(days),
                                  onTap: () => _update(_a.copyWith(days: days)),
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
                                      selected: _a.days.contains(i + 1),
                                      onTap: () {
                                        final days = {..._a.days};
                                        days.contains(i + 1) ? days.remove(i + 1) : days.add(i + 1);
                                        _update(_a.copyWith(days: days));
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
                      title: 'Routine to stop it',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final r in routines)
                                ChoicePill(
                                  label: r.name,
                                  selected: _a.routineId == r.id,
                                  onTap: () => _update(_a.copyWith(routineId: r.id)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(routineById(routines, _a.routineId).summary, style: text.bodySmall),
                        ],
                      ),
                    ),
                    FormSection(
                      title: 'Label',
                      child: TextField(
                        controller: _label,
                        decoration: const InputDecoration(hintText: 'Wake-up workout'),
                      ),
                    ),
                    FormSection(
                      title: 'Sound',
                      child: Column(
                        children: [
                          for (final s in AlarmSound.values)
                            _SoundRow(
                              sound: s,
                              selected: _a.sound == s,
                              playing: _previewing == s,
                              onTap: () => _preview(s),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.volume_down_rounded, color: AppColors.textSecondary),
                              Expanded(
                                child: Slider(
                                  value: _a.volume,
                                  min: 0.3,
                                  max: 1,
                                  activeColor: AppColors.primary,
                                  inactiveColor: AppColors.surfaceHigh,
                                  onChanged: (v) {
                                    _update(_a.copyWith(volume: v));
                                    _player.setVolume(v).catchError((_) {});
                                  },
                                ),
                              ),
                              const Icon(Icons.volume_up_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                          SettingToggle(
                            icon: Icons.trending_up_rounded,
                            title: 'Gradually increase volume',
                            subtitle: 'Starts soft and builds up over 20 seconds',
                            value: _a.fadeIn,
                            onChanged: (v) => _update(_a.copyWith(fadeIn: v)),
                          ),
                          SettingToggle(
                            icon: Icons.vibration_rounded,
                            title: 'Vibrate',
                            value: _a.vibrate,
                            onChanged: (v) => _update(_a.copyWith(vibrate: v)),
                          ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: 'Snooze',
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _a.hardMode ? 0.4 : 1,
                        child: IgnorePointer(
                          ignoring: _a.hardMode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SegmentedPills(
                                options: const ['Off', '1×', '2×', '3×'],
                                index: _a.maxSnoozes,
                                onChanged: (i) => _update(_a.copyWith(maxSnoozes: i)),
                              ),
                              const SizedBox(height: 10),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                child: _a.maxSnoozes == 0
                                    ? const SizedBox(width: double.infinity)
                                    : Wrap(
                                        spacing: 8,
                                        children: [
                                          for (final m in [3, 5, 10])
                                            ChoicePill(
                                              label: '$m min',
                                              selected: _a.snoozeMinutes == m,
                                              onTap: () => _update(_a.copyWith(snoozeMinutes: m)),
                                            ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FormSection(
                      title: 'Challenge',
                      child: SettingToggle(
                        icon: Icons.local_fire_department_rounded,
                        title: 'Hard mode',
                        subtitle: 'No snooze and no emergency stop — the workout is the only way out',
                        value: _a.hardMode,
                        onChanged: (v) => _update(_a.copyWith(hardMode: v)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GradientButton(label: 'Save alarm', icon: Icons.check_rounded, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.sound, required this.selected, required this.playing, required this.onTap});

  final AlarmSound sound;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.5) : AppColors.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : AppColors.surfaceHigh,
              ),
              child: Icon(
                playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(sound.label, style: text.titleSmall)),
            if (playing)
              const _Equalizer()
            else if (selected)
              const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Three bouncing bars shown while a ringtone previews.
class _Equalizer extends StatelessWidget {
  const _Equalizer();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 3; i++)
        Container(
              width: 3,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 120).ms)
            .scaleY(begin: 0.3, end: 1, duration: 350.ms, alignment: Alignment.bottomCenter),
    ],
  );
}
