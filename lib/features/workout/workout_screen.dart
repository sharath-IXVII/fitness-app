import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/alarm_scheduler.dart';
import '../alarm/app_permissions.dart';
import '../alarm/domain/challenge.dart';
import '../alarm/strict_mode.dart';
import '../challenge/challenge_screen.dart';
import '../streaks/daily_log_providers.dart';
import '../friends/domain/friends.dart';
import '../friends/friends_providers.dart';
import 'domain/rep_counter.dart';
import 'domain/routine.dart';
import 'domain/workout_session.dart';
import 'pose_camera.dart';
import 'routine_providers.dart';
import 'widgets/exercise_demo.dart';
import 'widgets/skeleton_painter.dart';
import 'workout_done_screen.dart';

class WorkoutArgs {
  const WorkoutArgs({this.routineId = '', this.ring, this.routine, this.challenge});

  final String routineId;

  /// A one-off routine (a friend challenge) instead of a saved one.
  final Routine? routine;

  /// Set when this workout is a friend challenge; counted reps complete it.
  final FriendChallenge? challenge;

  /// Set when the workout was started from a ringing alarm; null for practice.
  final RingInfo? ring;
}

enum _Phase { starting, noCamera, getReady, active }

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.args});

  final WorkoutArgs args;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  late final Routine _routine = widget.args.routine ?? routineById(ref.read(routinesProvider), widget.args.routineId);
  late final WorkoutSession _session = WorkoutSession(_routine);
  late final PoseCamera _camera = PoseCamera(onPose: _onPose);
  final _clock = Stopwatch()..start();

  _Phase _phase = _Phase.starting;
  int _countdown = 5;
  Timer? _countdownTimer;
  Landmarks? _landmarks;
  Size _imageSize = Size.zero;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  int _repPulse = 0;
  Duration _lastWatchdogArm = Duration.zero;
  bool _finishing = false;

  bool get _alarmMode => widget.args.ring != null;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _start();
  }

  Future<void> _start() async {
    final ring = widget.args.ring;
    if (ring != null) {
      // Silence the ring while the user works out; the watchdog re-rings if
      // they stop moving or leave this screen.
      await AlarmScheduler.silence(ring);
      await AlarmScheduler.armWatchdog(ring);
      _lastWatchdogArm = _clock.elapsed;
    }
    // The permission dialog mustn't be covered by strict mode's bring-back,
    // and a stuck dialog mustn't trap the user: fall back after 60 s.
    final allowed = await StrictMode.whileAway(AppPermissions.camera)
        .timeout(const Duration(seconds: 60), onTimeout: () => false);
    if (!allowed) {
      if (mounted) setState(() => _phase = _Phase.noCamera);
      return;
    }
    try {
      await _camera.start();
    } catch (e) {
      debugPrint('camera failed: $e');
      if (mounted) setState(() => _phase = _Phase.noCamera);
      return;
    }
    if (mounted) _getReady();
  }

  void _getReady() {
    _countdownTimer?.cancel();
    setState(() {
      _phase = _Phase.getReady;
      // More time before the first exercise to place the phone.
      _countdown = _session.stepIndex == 0 ? 10 : 5;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      HapticFeedback.selectionClick();
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _phase = _Phase.active);
      }
    });
  }

  void _onPose(Landmarks? landmarks, Size size, InputImageRotation rotation) {
    if (!mounted) return;
    _landmarks = landmarks;
    _imageSize = size;
    _rotation = rotation;
    if (_phase != _Phase.active || _finishing) {
      setState(() {});
      return;
    }
    final event = _session.update(landmarks, _clock.elapsed);
    switch (event) {
      case SessionEvent.rep:
        HapticFeedback.mediumImpact();
        _repPulse++;
        _keepWatchdogAway();
      case SessionEvent.stepDone:
        HapticFeedback.heavyImpact();
        _keepWatchdogAway(force: true);
        _getReady();
      case SessionEvent.finished:
        _finish();
      case SessionEvent.none:
        break;
    }
    setState(() {});
  }

  /// Pushes the idle re-ring further out while the user keeps moving.
  Future<void> _keepWatchdogAway({bool force = false}) async {
    final ring = widget.args.ring;
    if (ring == null) return;
    if (!force && _clock.elapsed - _lastWatchdogArm < const Duration(seconds: 15)) return;
    _lastWatchdogArm = _clock.elapsed;
    if (await AlarmScheduler.isRinging(AlarmScheduler.watchdogId)) {
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
    }
    await AlarmScheduler.armWatchdog(ring);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    HapticFeedback.heavyImpact();
    final ring = widget.args.ring;
    if (ring != null) {
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
      await ref.read(alarmsProvider.notifier).handled(ring.alarmId);
      if (ring.strict) await StrictMode.release(ref.read(sharedPrefsProvider));
    }
    // A friend challenge only counts if every rep was counted by the camera
    // (practice mode lets people skip).
    final challenge = widget.args.challenge;
    ChallengeOutcome? outcome;
    if (challenge != null) {
      final counted = [
        for (var i = 0; i < _routine.steps.length; i++)
          i < _session.results.length && _session.results[i] >= _routine.steps[i].target,
      ];
      final backend = ref.read(friendsBackendProvider);
      final uid = ref.read(friendsUidProvider);
      if (!counted.every((ok) => ok)) {
        outcome = ChallengeOutcome.notCounted;
      } else if (backend == null || uid == null) {
        outcome = ChallengeOutcome.notSaved;
      } else {
        try {
          await backend.markDone(challenge, uid).timeout(const Duration(seconds: 15));
          outcome = ChallengeOutcome.done;
        } catch (e) {
          debugPrint('challenge not saved: $e');
          outcome = ChallengeOutcome.notSaved;
        }
      }
    }
    // Practice mode allows skipping; only a workout that was actually done
    // counts for today.
    final completed = [
      for (var i = 0; i < _routine.steps.length; i++)
        if (i < _session.results.length && _session.results[i] >= _routine.steps[i].target) i,
    ];
    if (_alarmMode || completed.length == _routine.steps.length) {
      await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(workoutDone: true));
    }
    if (!mounted) return;
    context.go(
      Routes.workoutDone,
      extra: WorkoutDoneArgs(
        routine: _routine,
        results: _session.results,
        duration: _clock.elapsed,
        fromAlarm: _alarmMode,
        challenge: outcome,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _camera.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_alarmMode,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            // Soft fade so the overlays stay readable on any background.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
                  stops: [0, 0.22, 0.55, 1],
                ),
              ),
            ),
            SafeArea(child: Column(children: [_topBar(), const Spacer(), if (_phase == _Phase.active) _hud()])),
            if (_phase == _Phase.getReady) _getReadyOverlay(),
            if (_phase == _Phase.starting) const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (_phase == _Phase.noCamera) _noCamera(),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final c = _camera.controller;
    if (c == null || !c.value.isInitialized || c.value.previewSize == null) return const SizedBox.shrink();
    final preview = c.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // previewSize is reported in landscape; the app is portrait.
          width: preview.height,
          height: preview.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(c),
              CustomPaint(
                painter: SkeletonPainter(
                  landmarks: _landmarks,
                  imageSize: _imageSize,
                  rotation: _rotation,
                  mirrored: _camera.isFront,
                  good: _session.counter.visible && _session.counter.hint == null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (!_alarmMode)
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _alarmMode ? 'Keep going: the alarm rings again if you stop' : '${_routine.name} · practice',
                  style: text.titleSmall?.copyWith(color: Colors.white),
                ),
              ),
              Text(
                'Step ${_session.stepIndex + 1} of ${_routine.steps.length}',
                style: text.labelMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < _routine.steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: i < _session.stepIndex
                            ? 1
                            : i == _session.stepIndex
                            ? _session.stepProgress
                            : 0,
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hud() {
    final text = Theme.of(context).textTheme;
    final step = _session.current;
    final counter = _session.counter;
    final hint = counter.hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hint == null
                ? const SizedBox(height: 44)
                : Container(
                    key: ValueKey(hint),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: counter.visible ? AppColors.gold : AppColors.steps,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hint,
                      style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(step.exercise.icon, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(step.exercise.label, style: text.titleLarge),
                    const Spacer(),
                    if (!_alarmMode)
                      TextButton(
                        onPressed: () {
                          final e = _session.skip();
                          if (e == SessionEvent.finished) {
                            _finish();
                          } else {
                            _getReady();
                          }
                        },
                        child: const Text('Skip'),
                      ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${counter.progress}',
                      key: ValueKey(_repPulse),
                      style: text.displayLarge?.copyWith(fontSize: 88, color: AppColors.primary, height: 1),
                    ).animate().scaleXY(begin: 1.08, end: 1, duration: 200.ms, curve: Curves.easeOutCubic),
                    const SizedBox(width: 6),
                    Text(
                      '/ ${step.exercise.formatTarget(step.target)}',
                      style: text.headlineSmall?.copyWith(color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    if (_session.next != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Next', style: text.labelSmall),
                          Text(_session.next!.exercise.label, style: text.titleSmall),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: counter.motion,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    step.exercise.timed ? 'Hold steady' : 'Movement depth',
                    style: text.labelSmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _getReadyOverlay() {
    final text = Theme.of(context).textTheme;
    final step = _session.current;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _session.stepIndex == 0 ? 'Get ready' : 'Nice! Next up',
            style: text.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(step.exercise.label, style: text.headlineMedium?.copyWith(color: Colors.white)),
          Text(
            step.exercise.timed ? 'Hold for ${step.target} seconds' : '${step.target} reps',
            style: text.titleMedium?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ExerciseDemo(exercise: step.exercise, height: 170, dark: true),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(step.exercise.tip, style: text.bodyMedium?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$_countdown',
            key: ValueKey(_countdown),
            style: text.displayLarge?.copyWith(fontSize: 72, color: Colors.white),
          ).animate().scaleXY(begin: 1.3, end: 1, duration: 350.ms).fadeIn(duration: 200.ms),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _noCamera() {
    final text = Theme.of(context).textTheme;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Camera needed', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'The camera counts your reps. Nothing is recorded or uploaded — it all happens on your phone.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Allow camera',
            onPressed: () async {
              setState(() => _phase = _Phase.starting);
              await _start();
            },
          ),
          TextButton(
            onPressed: () => StrictMode.whileAway(AppPermissions.openSettings),
            child: const Text('Open settings'),
          ),
          if (!_alarmMode) TextButton(onPressed: () => context.pop(), child: const Text('Back')),
          // Without a camera the alarm can still be turned off the hard way.
          if (_alarmMode)
            TextButton(
              onPressed: () => context.go(
                Routes.challenge,
                extra: ChallengeArgs(
                  challenge: AlarmChallenge.mixed,
                  level: ChallengeLevel.hard,
                  ring: widget.args.ring,
                ),
              ),
              child: const Text('No camera? Solve hard brain games instead'),
            ),
        ],
      ),
    );
  }
}
