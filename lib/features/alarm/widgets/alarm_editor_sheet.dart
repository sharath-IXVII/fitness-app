import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
                          _Wheel(
                            count: 24,
                            value: _a.time.hour,
                            onChanged: (v) => _update(
                              _a.copyWith(
                                time: TimeOfDay(hour: v, minute: _a.time.minute),
                              ),
                            ),
                          ),
                          Text(':', style: text.displaySmall),
                          _Wheel(
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
                    _Section(
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
                                _Chip(
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
                                    child: _DayDot(
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
                    _Section(
                      title: 'Routine to stop it',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final r in routines)
                                _Chip(
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
                    _Section(
                      title: 'Label',
                      child: TextField(
                        controller: _label,
                        decoration: const InputDecoration(hintText: 'Wake-up workout'),
                      ),
                    ),
                    _Section(
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
                          _ToggleRow(
                            icon: Icons.trending_up_rounded,
                            title: 'Gradually increase volume',
                            subtitle: 'Starts soft and builds up over 20 seconds',
                            value: _a.fadeIn,
                            onChanged: (v) => _update(_a.copyWith(fadeIn: v)),
                          ),
                          _ToggleRow(
                            icon: Icons.vibration_rounded,
                            title: 'Vibrate',
                            value: _a.vibrate,
                            onChanged: (v) => _update(_a.copyWith(vibrate: v)),
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'Snooze',
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _a.hardMode ? 0.4 : 1,
                        child: IgnorePointer(
                          ignoring: _a.hardMode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Segmented(
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
                                            _Chip(
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
                    _Section(
                      title: 'Challenge',
                      child: _ToggleRow(
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.93,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
    ),
  );
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.88,
    child: AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.surfaceHigh,
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
        ),
      ),
    ),
  );
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: value ? AppColors.primary : AppColors.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                if (subtitle != null) Text(subtitle!, style: text.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Segmented control with a sliding highlight.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.index, required this.onChanged});

  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + 2 * index / (options.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / options.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppColors.softShadow(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, o) in options.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: Center(
                      child: Text(
                        o,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i == index ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
