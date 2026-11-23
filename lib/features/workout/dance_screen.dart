import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/progress_ring.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/alarm_scheduler.dart';
import '../alarm/app_permissions.dart';
import '../alarm/domain/challenge.dart';
import '../alarm/strict_mode.dart';
import '../challenge/challenge_screen.dart';
import 'domain/dance_meter.dart';
import 'domain/rep_counter.dart';
import 'pose_camera.dart';
import 'widgets/skeleton_painter.dart';

/// Dance for 20 seconds in front of the camera to switch the alarm off.
/// [ring] is null when trying it out from the alarm editor.
class DanceScreen extends ConsumerStatefulWidget {
  const DanceScreen({super.key, this.ring});

  final RingInfo? ring;

  @override
  ConsumerState<DanceScreen> createState() => _DanceScreenState();
}

enum _Phase { starting, noCamera, getReady, dancing, done }

class _DanceScreenState extends ConsumerState<DanceScreen> {
  final _meter = DanceMeter();
  late final PoseCamera _camera = PoseCamera(onPose: _onPose);
  final _clock = Stopwatch()..start();
  final _music = AudioPlayer();
  _Phase _phase = _Phase.starting;
  int _countdown = 5;
  Timer? _countdownTimer;
  Landmarks? _landmarks;
  Size _imageSize = Size.zero;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  Duration _lastArm = Duration.zero;
  int _lastBuzz = 20;
  bool _finishing = false;

  RingInfo? get _ring => widget.ring;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _start();
  }

  Future<void> _start() async {
    final ring = _ring;
    if (ring != null) {
      // Quiet while dancing; the watchdog rings again if they stop.
      await AlarmScheduler.silence(ring);
      await AlarmScheduler.armWatchdog(ring);
      _lastArm = _clock.elapsed;
    }
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
    if (!mounted) return;
    setState(() {
      _phase = _Phase.getReady;
      _countdown = 5;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      HapticFeedback.selectionClick();
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _phase = _Phase.dancing);
        _playMusic();
      }
    });
  }

  Future<void> _playMusic() async {
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource('sounds/dance_beat.wav'), volume: 0.9);
    } catch (_) {
      // Music is a bonus; dancing works without it.
    }
  }

  void _onPose(Landmarks? landmarks, Size size, InputImageRotation rotation) {
    if (!mounted) return;
    _landmarks = landmarks;
    _imageSize = size;
    _rotation = rotation;
    if (_phase == _Phase.dancing && !_finishing) {
      final before = _meter.danced;
      _meter.update(landmarks, _clock.elapsed);
      if (_meter.danced > before) _keepWatchdogAway();
      // A tap on each full second, a bigger one at the last five.
      final left = _meter.secondsLeft;
      if (left < _lastBuzz) {
        _lastBuzz = left;
        left <= 5 ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
      }
      if (_meter.done) _finish();
    }
    setState(() {});
  }

  Future<void> _keepWatchdogAway() async {
    final ring = _ring;
    if (ring == null || _finishing || _clock.elapsed - _lastArm < const Duration(seconds: 10)) return;
    _lastArm = _clock.elapsed;
    if (await AlarmScheduler.isRinging(AlarmScheduler.watchdogId)) {
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
    }
    if (_finishing) return;
    await AlarmScheduler.armWatchdog(ring);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    HapticFeedback.heavyImpact();
    unawaited(_music.stop().catchError((_) {}));
    final ring = _ring;
    if (ring != null) {
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
      await AlarmScheduler.silence(ring);
      await ref.read(alarmsProvider.notifier).handled(ring.alarmId);
      if (ring.strict) await StrictMode.release(ref.read(sharedPrefsProvider));
      // In case a re-arm was mid-flight.
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
    }
    await _camera.dispose();
    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _camera.dispose();
    _music.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _ring == null || _phase == _Phase.done,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (_phase) {
          _Phase.done => _done(),
          _Phase.noCamera => _noCamera(),
          _ => Stack(
            fit: StackFit.expand,
            children: [
              _preview(),
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
              SafeArea(child: Column(children: [_topBar(), const Spacer(), if (_phase == _Phase.dancing) _hud()])),
              if (_phase == _Phase.getReady) _getReady(),
              if (_phase == _Phase.starting) const Center(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        },
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
                  good: _meter.visible && _meter.hint == null,
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
      child: Row(
        children: [
          if (_ring == null)
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              _ring != null ? tr('Keep dancing: the alarm rings again if you stop') : tr('Dance · practice'),
              style: text.titleSmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hud() {
    final text = Theme.of(context).textTheme;
    final hint = _meter.hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                      color: _meter.visible ? AppColors.gold : AppColors.steps,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tr(hint),
                      style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          ProgressRing(
            progress: _meter.progress,
            color: AppColors.energy,
            secondaryColor: AppColors.energyLight,
            trackColor: Colors.white24,
            size: 170,
            stroke: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_meter.secondsLeft}',
                  style: text.displayLarge?.copyWith(color: Colors.white, fontSize: 64, height: 1),
                ),
                Text(tr('seconds left'), style: text.labelMedium?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // How hard they are moving, live.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _meter.energy,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(tr('Energy'), style: text.labelSmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _getReady() {
    final text = Theme.of(context).textTheme;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 10),
          Text(tr('Dance for 20 seconds'), style: text.headlineMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            tr('Stand the phone up, step back so your whole body is in view, and move your arms and legs.'),
            style: text.bodyMedium?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Text(
            '$_countdown',
            key: ValueKey(_countdown),
            style: text.displayLarge?.copyWith(fontSize: 72, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _done() {
    final text = Theme.of(context).textTheme;
    final practice = _ring == null;
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(28),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
              child: const Icon(Icons.music_note_rounded, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text(practice ? tr('Nice moves!') : tr('Alarm off. What a way to wake up!'), style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              practice ? tr('This is what your alarm will ask for.') : tr('20 seconds of dancing. You are awake now.'),
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            GradientButton(
              label: practice ? tr('Done') : tr('Go to Today'),
              onPressed: () => practice ? context.pop() : context.go(Routes.home),
            ),
          ],
        ),
      ),
    );
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
          Text(tr('Camera needed'), style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            tr('The camera sees you dance. Nothing is recorded or uploaded; it all happens on your phone.'),
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: tr('Allow camera'),
            onPressed: () async {
              setState(() => _phase = _Phase.starting);
              await _start();
            },
          ),
          TextButton(
            onPressed: () => StrictMode.whileAway(AppPermissions.openSettings),
            child: Text(tr('Open settings')),
          ),
          if (_ring == null) TextButton(onPressed: () => context.pop(), child: Text(tr('Back'))),
          // Without a camera the alarm can still be turned off the hard way.
          if (_ring != null)
            TextButton(
              onPressed: () => context.go(
                Routes.challenge,
                extra: ChallengeArgs(challenge: AlarmChallenge.mixed, level: ChallengeLevel.hard, ring: _ring),
              ),
              child: Text(tr('No camera? Solve hard brain games instead')),
            ),
        ],
      ),
    );
  }
}
