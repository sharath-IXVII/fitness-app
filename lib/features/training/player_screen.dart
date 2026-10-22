import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../workout/widgets/exercise_demo.dart';
import 'domain/plans.dart';
import 'training_done_screen.dart';
import 'training_providers.dart';
import 'voice_coach.dart';
import 'widgets/move_widgets.dart';

enum _Phase { ready, work, rest }

/// Plays a guided workout: get ready → exercise → rest → … → done. Rep
/// exercises finish with a tap; timed ones count down. No camera needed.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.workout});

  final TrainingWorkout workout;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _readySeconds = 10;

  late final List<WorkoutItem> _items = widget.workout.items;
  late final VoiceCoach _coach = ref.read(voiceCoachProvider);
  final _active = Stopwatch();
  Timer? _ticker;

  _Phase _phase = _Phase.ready;
  int _index = 0;

  /// Seconds left in a countdown (ready, rest, timed work); seconds spent on
  /// a rep exercise.
  int _left = _readySeconds;
  int _total = _readySeconds;
  int _workSeconds = 0;
  bool _paused = false;
  bool _finishing = false;

  WorkoutItem get _item => _items[_index];
  bool get _voice => ref.read(trainingProvider).voice;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _restartTicker();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _say('Get ready. First up: ${_item.move.name}, ${_spoken(_item)}.'),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _coach.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  /// Restarts the one-second tick so each phase gets a full first second.
  void _restartTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _say(String s) {
    if (_voice) _coach.say(s);
  }

  String _spoken(WorkoutItem i) {
    final base = i.timed ? '${i.target} seconds' : '${i.target} reps';
    return i.move.perSide ? '$base each side' : base;
  }

  void _tick() {
    if (!mounted || _paused || _finishing) return;
    if (_phase == _Phase.work && !_item.timed) {
      setState(() => _workSeconds++);
      return;
    }
    setState(() => _left--);
    if (_phase == _Phase.work && _item.move.perSide && _left == _total ~/ 2) {
      HapticFeedback.heavyImpact();
      _say('Switch sides');
    } else if (_left > 0 && _left <= 3) {
      HapticFeedback.selectionClick();
      _say('$_left');
    }
    if (_left <= 0) {
      switch (_phase) {
        case _Phase.ready || _Phase.rest:
          _startWork();
        case _Phase.work:
          _next();
      }
    }
  }

  void _startWork() {
    HapticFeedback.heavyImpact();
    _active.start();
    _restartTicker();
    final secs = _item.timed ? _item.target * (_item.move.perSide ? 2 : 1) : 0;
    setState(() {
      _phase = _Phase.work;
      _left = _total = secs;
      _workSeconds = 0;
    });
    _say(_item.timed ? 'Go! ${_item.move.name}' : 'Go! ${_item.move.name}, ${_spoken(_item)}');
  }

  /// Finishes the current exercise and rests before the next one.
  void _next() {
    HapticFeedback.mediumImpact();
    if (_index + 1 >= _items.length) {
      _finish();
      return;
    }
    final rest = widget.workout.restSec;
    _restartTicker();
    setState(() {
      _index++;
      _phase = _Phase.rest;
      _left = _total = rest;
    });
    _say('Rest. Next: ${_item.move.name}, ${_spoken(_item)}.');
  }

  void _previous() {
    if (_index == 0) return;
    setState(() => _index--);
    _startWork();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _active.stop();
      _coach.stop();
    } else if (_phase != _Phase.ready) {
      _active.start();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _active.stop();
    _ticker?.cancel();
    _say('Workout complete. Great job!');
    final w = widget.workout;
    final seconds = _active.elapsed.inSeconds.clamp(1, 1 << 20);
    final kcal = w.kcal(ref.read(profileProvider)?.weightKg ?? 65, seconds);
    final training = ref.read(trainingProvider.notifier);
    await training.record(WorkoutRecord(title: w.title, at: DateTime.now(), seconds: seconds, kcal: kcal));
    if (w.challengeId != null && w.day != null) await training.completeDay(w.challengeId!, w.day!);
    await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(workoutDone: true));
    if (!mounted) return;
    context.pushReplacement(
      Routes.trainingDone,
      extra: TrainingDoneArgs(workout: w, seconds: seconds, kcal: kcal),
    );
  }

  Future<void> _confirmQuit() async {
    final wasPaused = _paused;
    if (!wasPaused) _togglePause();
    final quit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quit workout?'),
        content: const Text("You're doing great. This workout won't be saved if you quit now."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quit')),
          FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep going')),
        ],
      ),
    );
    if (!mounted) return;
    if (quit == true) {
      context.pop();
    } else if (!wasPaused) {
      _togglePause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rest = _phase == _Phase.rest;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: rest ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: rest ? AppColors.ink : AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  index: _index,
                  count: _items.length,
                  dark: rest,
                  voice: ref.watch(trainingProvider).voice,
                  onClose: _confirmQuit,
                  onVoice: () => ref.read(trainingProvider.notifier).setVoice(!_voice),
                  onInfo: () => showMoveHowTo(context, _item.move, item: _item),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey('$_phase-$_index'),
                      child: switch (_phase) {
                        _Phase.ready => _readyView(),
                        _Phase.work => _workView(),
                        _Phase.rest => _restView(),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demo({double height = 270}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.stroke),
    ),
    child: ExerciseDemo.move(demoId: _item.move.demo, label: _item.move.name, height: height),
  );

  Widget _readyView() {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        _demo(),
        const Spacer(),
        Text('GET READY', style: text.labelLarge?.copyWith(color: AppColors.energy, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(_item.move.name, style: text.headlineMedium, textAlign: TextAlign.center),
        Text(_item.label, style: text.titleMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        _Countdown(left: _left, total: _total, paused: _paused, onTap: _togglePause),
        const Spacer(),
        TextButton.icon(
          onPressed: _startWork,
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text("I'm ready, start"),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _workView() {
    final text = Theme.of(context).textTheme;
    final timed = _item.timed;
    return Column(
      children: [
        const SizedBox(height: 8),
        _demo(),
        const Spacer(),
        Text(_item.move.name, style: text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        if (timed)
          _Countdown(left: _left, total: _total, paused: _paused, onTap: _togglePause)
        else ...[
          Text(
            '×${_item.target}',
            style: text.displayMedium?.copyWith(color: AppColors.primary),
          ).animate(key: ValueKey(_index)).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          if (_item.move.perSide) Text('each side', style: text.titleMedium?.copyWith(color: AppColors.textSecondary)),
          Text(_clock(_workSeconds), style: text.bodyMedium?.copyWith(color: AppColors.textTertiary)),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              _RoundButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Previous exercise',
                onTap: _index > 0 ? _previous : null,
              ),
              const Spacer(),
              timed
                  ? _BigButton(
                      icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      label: _paused ? 'Resume' : 'Pause',
                      onTap: _togglePause,
                    )
                  : _BigButton(icon: Icons.check_rounded, label: 'Done', onTap: _next),
              const Spacer(),
              _RoundButton(icon: Icons.skip_next_rounded, tooltip: 'Skip exercise', onTap: _next),
            ],
          ),
        ),
      ],
    );
  }

  Widget _restView() {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const Spacer(),
        Text('REST', style: text.labelLarge?.copyWith(color: AppColors.energyLight, letterSpacing: 3)),
        const SizedBox(height: 8),
        Text(
          _clock(_left),
          style: text.displayLarge?.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Pill(label: '+20s', onTap: () => setState(() => _left += 20)),
            const SizedBox(width: 12),
            _Pill(label: 'Skip', filled: true, onTap: _startWork),
          ],
        ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT UP · ${_index + 1}/${_items.length}',
                style: text.labelSmall?.copyWith(color: AppColors.textTertiary, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_item.move.name, style: text.titleLarge),
                        Text(_item.label, style: text.titleSmall?.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: ExerciseDemo.move(demoId: _item.move.demo, label: _item.move.name, height: 100),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.count,
    required this.dark,
    required this.voice,
    required this.onClose,
    required this.onVoice,
    required this.onInfo,
  });

  final int index;
  final int count;
  final bool dark;
  final bool voice;
  final VoidCallback onClose;
  final VoidCallback onVoice;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quit workout',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: fg),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i < index
                            ? AppColors.energy
                            : i == index
                            ? AppColors.energyLight
                            : (dark ? Colors.white12 : AppColors.stroke),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: voice ? 'Mute voice coach' : 'Turn on voice coach',
            onPressed: onVoice,
            icon: Icon(voice ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: fg),
          ),
          IconButton(
            tooltip: 'How to do it',
            onPressed: onInfo,
            icon: Icon(Icons.info_outline_rounded, color: fg),
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.left, required this.total, required this.paused, required this.onTap});

  final int left;
  final int total;
  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: paused ? 'Paused, $left seconds left. Tap to resume' : '$left seconds left. Tap to pause',
      child: GestureDetector(
        onTap: onTap,
        child: ProgressRing(
          progress: total == 0 ? 0 : left / total,
          color: AppColors.energy,
          secondaryColor: AppColors.energyLight,
          size: 132,
          stroke: 10,
          child: paused
              ? const Icon(Icons.play_arrow_rounded, size: 52, color: AppColors.energy)
              : Text('$left', style: text.displayMedium),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.energyGradient,
          boxShadow: AppColors.softShadow(AppColors.energy),
        ),
        child: Icon(icon, color: Colors.white, size: 42),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onTap,
    iconSize: 28,
    style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh, fixedSize: const Size(56, 56)),
    icon: Icon(icon, color: onTap == null ? AppColors.textMuted : AppColors.textPrimary),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        color: filled ? AppColors.energy : Colors.white12,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
    ),
  );
}
