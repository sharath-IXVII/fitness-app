import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../alarm/domain/challenge.dart';
import '../domain/games.dart';

/// Watch tiles light up, then tap them in the same order. Two rounds, the
/// second one tile longer. A mistake replays the same pattern.
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key, required this.level, required this.rng, required this.onProgress, required this.onDone});

  final ChallengeLevel level;
  final math.Random rng;
  final VoidCallback onProgress;
  final VoidCallback onDone;

  /// Time each tile stays lit while showing the pattern.
  static const lit = Duration(milliseconds: 550);
  static const gap = Duration(milliseconds: 250);

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  late final _spec = memorySpec(widget.level);
  int _round = 0;
  late List<int> _pattern = memoryPattern(_spec.side, _spec.length, widget.rng);
  int? _showing;
  bool _watching = true;
  int _next = 0;
  int? _wrongTile;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _after(Duration d, VoidCallback f) => _timers.add(Timer(d, () => mounted ? f() : null));

  void _play() {
    setState(() {
      _watching = true;
      _next = 0;
      _showing = null;
    });
    var t = const Duration(milliseconds: 700);
    for (final tile in _pattern) {
      _after(t, () => setState(() => _showing = tile));
      t += MemoryGame.lit;
      _after(t, () => setState(() => _showing = null));
      t += MemoryGame.gap;
    }
    _after(t, () => setState(() => _watching = false));
  }

  void _tap(int i) {
    if (_watching) return;
    if (_pattern[_next] == i) {
      HapticFeedback.selectionClick();
      setState(() => _next++);
      if (_next == _pattern.length) {
        HapticFeedback.mediumImpact();
        widget.onProgress();
        if (_round + 1 >= memoryRounds) {
          widget.onDone();
          return;
        }
        _after(const Duration(milliseconds: 500), () {
          _round++;
          _pattern = memoryPattern(_spec.side, _spec.length + _round, widget.rng);
          _play();
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _wrongTile = i);
      _after(const Duration(milliseconds: 600), () {
        setState(() => _wrongTile = null);
        _play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final side = _spec.side;
    return Column(
      children: [
        Text('Round ${_round + 1} of $memoryRounds', style: text.labelLarge),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _watching ? 'Watch the pattern' : 'Your turn — ${_pattern.length - _next} to go',
            key: ValueKey(_watching ? 'w' : 't$_next'),
            style: text.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: side,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < side * side; i++)
                    Semantics(
                      button: true,
                      label: 'Tile ${i + 1}',
                      child: GestureDetector(
                        onTap: () => _tap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: _wrongTile == i
                                ? AppColors.danger.withValues(alpha: 0.7)
                                : _showing == i || (!_watching && _pattern.take(_next).contains(i))
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.stroke),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ).animate(key: ValueKey(_wrongTile != null)).shakeX(hz: _wrongTile != null ? 6 : 0, amount: 5),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
