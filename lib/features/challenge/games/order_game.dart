import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../alarm/domain/challenge.dart';
import '../domain/games.dart';

/// A shuffled grid: tap 1, 2, 3 … in order.
class OrderGame extends StatefulWidget {
  const OrderGame({super.key, required this.level, required this.rng, required this.onProgress, required this.onDone});

  final ChallengeLevel level;
  final math.Random rng;
  final VoidCallback onProgress;
  final VoidCallback onDone;

  @override
  State<OrderGame> createState() => _OrderGameState();
}

class _OrderGameState extends State<OrderGame> {
  late final _side = orderSide(widget.level);
  late final _grid = orderGrid(_side, widget.rng);
  int _next = 1;
  int? _wrong;
  Timer? _clear;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  void _tap(int n) {
    if (n < _next) return;
    if (n == _next) {
      HapticFeedback.selectionClick();
      setState(() => _next++);
      if (_next % 4 == 0) widget.onProgress();
      if (_next > _grid.length) widget.onDone();
    } else {
      HapticFeedback.heavyImpact();
      _clear?.cancel();
      setState(() => _wrong = n);
      _clear = Timer(const Duration(milliseconds: 450), () => mounted ? setState(() => _wrong = null) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = _next > _grid.length;
    return Column(
      children: [
        Text(done ? 'Done' : 'Tap $_next', style: text.headlineSmall),
        const SizedBox(height: 4),
        Text('${_next - 1} of ${_grid.length}', style: text.bodySmall),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: _side,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final n in _grid)
                    GestureDetector(
                      onTap: () => _tap(n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: n < _next
                              ? AppColors.primarySoft
                              : _wrong == n
                              ? AppColors.danger.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _wrong == n ? AppColors.danger : AppColors.stroke),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: n < _next ? 0.35 : 1,
                          child: Text('$n', style: (_side >= 5 ? text.titleMedium : text.titleLarge)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
