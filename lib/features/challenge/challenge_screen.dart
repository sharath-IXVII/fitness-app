import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/alarm_scheduler.dart';
import '../alarm/domain/challenge.dart';
import '../alarm/strict_mode.dart';
import 'domain/games.dart';
import 'games/math_game.dart';
import 'games/memory_game.dart';
import 'games/order_game.dart';

class ChallengeArgs {
  const ChallengeArgs({required this.challenge, required this.level, this.ring});

  final AlarmChallenge challenge;
  final ChallengeLevel level;

  /// Set when solving this turns an alarm off; null for practice.
  final RingInfo? ring;
}

/// Brain games that turn an alarm off — for mornings when the goal is to be
/// awake and thinking (to study, say) rather than to work out.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  final _rng = math.Random();
  late final List<GameKind> _games = gamesFor(
    widget.args.challenge == AlarmChallenge.workout ? AlarmChallenge.mixed : widget.args.challenge,
    _rng,
  );
  int _index = 0;
  bool _done = false;
  final _clock = Stopwatch()..start();
  Duration _lastArm = Duration.zero;

  RingInfo? get _ring => widget.args.ring;

  @override
  void initState() {
    super.initState();
    final ring = _ring;
    if (ring != null) {
      // Quiet while solving; the watchdog re-rings if the user stops.
      AlarmScheduler.silence(ring).then((_) => AlarmScheduler.armWatchdog(ring));
    }
  }

  /// Pushes the idle re-ring further out while the user is making progress.
  Future<void> _progress() async {
    final ring = _ring;
    if (ring == null || _clock.elapsed - _lastArm < const Duration(seconds: 10)) return;
    _lastArm = _clock.elapsed;
    if (await AlarmScheduler.isRinging(AlarmScheduler.watchdogId)) {
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
    }
    await AlarmScheduler.armWatchdog(ring);
  }

  Future<void> _gameDone() async {
    if (_index + 1 < _games.length) {
      HapticFeedback.mediumImpact();
      await _progress();
      setState(() => _index++);
      return;
    }
    HapticFeedback.heavyImpact();
    final ring = _ring;
    if (ring != null) {
      await AlarmScheduler.stop(AlarmScheduler.watchdogId);
      await AlarmScheduler.silence(ring);
      await ref.read(alarmsProvider.notifier).handled(ring.alarmId);
      if (ring.strict) await StrictMode.release(ref.read(sharedPrefsProvider));
    }
    if (mounted) setState(() => _done = true);
  }

  static String _title(GameKind g) => switch (g) {
    GameKind.math => 'Solve the sums',
    GameKind.memory => 'Remember the pattern',
    GameKind.order => 'Numbers in order',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final practice = _ring == null;
    final game = _games[_index];
    final key = ValueKey('$_index-${game.name}');
    final level = widget.args.level;
    final child = switch (game) {
      GameKind.math => MathGame(key: key, level: level, rng: _rng, onProgress: _progress, onDone: _gameDone),
      GameKind.memory => MemoryGame(key: key, level: level, rng: _rng, onProgress: _progress, onDone: _gameDone),
      GameKind.order => OrderGame(key: key, level: level, rng: _rng, onProgress: _progress, onDone: _gameDone),
    };

    return PopScope(
      canPop: practice || _done,
      child: Scaffold(
        appBar: practice && !_done ? AppBar(title: const Text('Try the challenge')) : null,
        body: PageBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _done
                    ? _Done(practice: practice)
                    : Column(
                        key: key,
                        children: [
                          if (_games.length > 1)
                            Text(
                              'GAME ${_index + 1} OF ${_games.length}',
                              style: text.labelSmall?.copyWith(letterSpacing: 1.4, color: AppColors.textTertiary),
                            ),
                          if (_ring?.strict ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _Badge(icon: Icons.lock_outline_rounded, label: 'Strict mode'),
                            ),
                          const SizedBox(height: 8),
                          Text(_title(game), style: text.headlineSmall),
                          const SizedBox(height: 18),
                          Expanded(child: child),
                        ],
                      ).animate().fadeIn(duration: 250.ms).moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary)),
      ],
    ),
  );
}

class _Done extends StatelessWidget {
  const _Done({required this.practice});

  final bool practice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('done'),
      children: [
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
          child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
        ).animate().scale(begin: const Offset(0.7, 0.7), duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 22),
        Text(practice ? 'Nicely done' : 'Alarm off. You\'re awake.', style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          practice ? 'This is what your alarm will ask for.' : 'Your mind is warmed up — a good moment to start.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        GradientButton(
          label: practice ? 'Done' : 'Go to Today',
          onPressed: () => practice ? context.pop() : context.go(Routes.home),
        ),
      ],
    );
  }
}
