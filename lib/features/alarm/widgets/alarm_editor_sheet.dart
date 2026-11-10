import '../../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/pressable.dart';
import '../../challenge/challenge_screen.dart';
import '../../workout/routine_providers.dart';
import '../alarm_providers.dart';
import '../app_permissions.dart';
import '../domain/workout_alarm.dart';
import '../strict_mode.dart';

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

  /// Switching a new alarm between wake-up and bedtime starts from that
  /// kind's own defaults.
  void _setKind(AlarmKind k) {
    if (k == _a.kind) return;
    final fresh = k == AlarmKind.sleep
        ? ref.read(alarmsProvider.notifier).sleepDraft()
        : ref.read(alarmsProvider.notifier).draft();
    _label.text = fresh.label;
    _update(fresh.copyWith(id: _a.id));
  }

  Future<void> _pickSleepEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _a.sleepEnd ~/ 60, minute: _a.sleepEnd % 60),
      helpText: 'Sleep mode ends at',
    );
    if (t != null) _update(_a.copyWith(sleepEnd: t.hour * 60 + t.minute));
  }

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
      label: _label.text.trim().isEmpty ? (_a.isSleep ? 'Bedtime' : 'Workout alarm') : _label.text.trim(),
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

  Future<void> _setStrict(bool on) async {
    _update(_a.copyWith(strict: on));
    if (!on || await StrictMode.canReopenItself() || !mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('One more permission')),
        content: Text(
          _a.isSleep
              ? 'To keep other apps blocked while you sleep, FittArc needs "Display over other apps". '
                    'On the next screen, find FittArc and turn it on.'
              : 'To bring the alarm back when someone leaves it, FittArc needs "Display over other apps". '
                    'On the next screen, find FittArc and turn it on.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Later'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Open settings'))),
        ],
      ),
    );
    if (open == true) await StrictMode.openReopenSettings();
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
                  Expanded(
                    child: Text(
                      widget.isNew ? 'New alarm' : (_a.isSleep ? 'Edit bedtime alarm' : 'Edit alarm'),
                      style: text.titleLarge,
                    ),
                  ),
                  if (!widget.isNew)
                    IconButton(
                      tooltip: tr('Delete'),
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
                    if (widget.isNew) ...[
                      SegmentedPills(
                        options: const ['Wake-up', 'Bedtime'],
                        index: _a.kind.index,
                        onChanged: (i) => _setKind(AlarmKind.values[i]),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 170,
                      child: ClockWheels(
                        time: _a.time,
                        onChanged: (t) => _update(_a.copyWith(time: t)),
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
                      title: tr('Repeat'),
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
                    if (!_a.isSleep)
                      FormSection(
                        title: tr('Strict mode: no cheating'),
                        child: Column(
                          children: [
                            SettingToggle(
                              icon: Icons.snooze_rounded,
                              title: tr('No snooze or emergency stop'),
                              subtitle: tr('Finishing the task is the only way to turn it off'),
                              value: _a.noEscape,
                              onChanged: _a.strict ? null : (v) => _update(_a.copyWith(hardMode: v)),
                            ),
                            SettingToggle(
                              icon: Icons.lock_outline_rounded,
                              title: tr('Strict mode'),
                              subtitle:
                                  'Full volume that the buttons can\'t lower, and your phone stays on the alarm until '
                                  'you finish. In an emergency, restart your phone to leave it.',
                              value: _a.strict,
                              onChanged: _setStrict,
                            ),
                          ],
                        ),
                      ),
                    if (_a.isSleep)
                      FormSection(
                        title: tr('Sleep mode'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('When this rings, tap "Start sleep mode" and your phone settles into a calm night screen.'),
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Pressable(
                              onTap: _pickSleepEnd,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.stroke),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.nightlight_round, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(tr('Sleep mode ends at'), style: text.titleSmall)),
                                    Text(
                                      TimeOfDay(hour: _a.sleepEnd ~/ 60, minute: _a.sleepEnd % 60).format(context),
                                      style: text.titleSmall?.copyWith(color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SettingToggle(
                              icon: Icons.lock_outline_rounded,
                              title: tr('Block other apps'),
                              subtitle:
                                  'Only phone calls work until it ends. In an emergency you can call, or restart your '
                                  'phone to unlock everything.',
                              value: _a.strict,
                              onChanged: _setStrict,
                            ),
                          ],
                        ),
                      ),
                    if (!_a.isSleep)
                      FormSection(
                        title: tr('Turn it off by'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (_, box) => Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final c in AlarmChallenge.values)
                                    SizedBox(
                                      width: (box.maxWidth - 8) / 2,
                                      child: _ChoiceTile(
                                        icon: c.icon,
                                        title: c.label,
                                        selected: _a.challenge == c,
                                        onTap: () => _update(_a.copyWith(challenge: c)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(_a.challenge.description, style: text.bodySmall),
                            const SizedBox(height: 10),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              alignment: Alignment.topCenter,
                              child: _a.challenge.isGame
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: SegmentedPills(
                                            options: [for (final l in ChallengeLevel.values) l.label],
                                            index: _a.level.index,
                                            onChanged: (i) => _update(_a.copyWith(level: ChallengeLevel.values[i])),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () => context.push(
                                            Routes.challenge,
                                            extra: ChallengeArgs(challenge: _a.challenge, level: _a.level),
                                          ),
                                          child: Text(tr('Try it')),
                                        ),
                                      ],
                                    )
                                  : Column(
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
                          ],
                        ),
                      ),
                    FormSection(
                      title: tr('Label'),
                      child: TextField(
                        controller: _label,
                        decoration: InputDecoration(hintText: _a.isSleep ? 'Bedtime' : 'Wake-up workout'),
                      ),
                    ),
                    FormSection(
                      title: tr('Sound'),
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
                              Icon(Icons.volume_down_rounded, color: AppColors.textSecondary),
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
                              Icon(Icons.volume_up_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                          SettingToggle(
                            icon: Icons.trending_up_rounded,
                            title: tr('Gradually increase volume'),
                            subtitle: tr('Starts soft and builds up over 20 seconds'),
                            value: _a.fadeIn,
                            onChanged: (v) => _update(_a.copyWith(fadeIn: v)),
                          ),
                          SettingToggle(
                            icon: Icons.vibration_rounded,
                            title: tr('Vibrate'),
                            value: _a.vibrate,
                            onChanged: (v) => _update(_a.copyWith(vibrate: v)),
                          ),
                        ],
                      ),
                    ),
                    FormSection(
                      title: tr('Snooze'),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: _a.noEscape ? 0.4 : 1,
                        child: IgnorePointer(
                          ignoring: _a.noEscape,
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GradientButton(label: tr('Save alarm'), icon: Icons.check_rounded, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact selectable tile with an icon, used for the challenge choice.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.icon, required this.title, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.5) : AppColors.stroke),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
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
              Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
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
