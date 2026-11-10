import 'dart:math' as math;

import '../../../core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../alarm/domain/challenge.dart';
import '../domain/games.dart';

/// Solve [mathCount] sums in a row on a built-in keypad.
class MathGame extends StatefulWidget {
  const MathGame({super.key, required this.level, required this.rng, required this.onProgress, required this.onDone});

  final ChallengeLevel level;
  final math.Random rng;
  final VoidCallback onProgress;
  final VoidCallback onDone;

  @override
  State<MathGame> createState() => _MathGameState();
}

class _MathGameState extends State<MathGame> {
  late MathProblem _problem = mathProblem(widget.level, widget.rng);
  String _entry = '';
  int _solved = 0;
  int _shake = 0;
  bool _wrong = false;

  int get _total => mathCount(widget.level);

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _wrong = false;
      if (k == '⌫') {
        if (_entry.isNotEmpty) _entry = _entry.substring(0, _entry.length - 1);
      } else if (_entry.length < 5) {
        _entry += k;
      }
    });
  }

  void _submit() {
    if (_entry.isEmpty) return;
    if (int.tryParse(_entry) == _problem.answer) {
      HapticFeedback.mediumImpact();
      widget.onProgress();
      if (_solved + 1 >= _total) {
        setState(() => _solved++);
        widget.onDone();
        return;
      }
      setState(() {
        _solved++;
        _entry = '';
        _problem = mathProblem(widget.level, widget.rng);
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = true;
        _shake++;
        _entry = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        _Dots(done: _solved, total: _total),
        const Spacer(),
        Text(
          _problem.text,
          key: ValueKey(_problem.text),
          style: text.displaySmall?.copyWith(fontWeight: FontWeight.w600),
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 18),
        Container(
          width: 200,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _wrong ? AppColors.danger : AppColors.stroke, width: 1.5),
          ),
          child: Text(
            _entry.isEmpty ? '?' : _entry,
            style: text.headlineMedium?.copyWith(color: _entry.isEmpty ? AppColors.textMuted : AppColors.textPrimary),
          ),
        ).animate(key: ValueKey(_shake), target: _shake > 0 ? 1 : 0).shakeX(hz: 6, amount: 6, duration: 350.ms),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: _wrong
              ? Text(tr('Not quite — try again'), style: text.bodySmall?.copyWith(color: AppColors.danger))
              : null,
        ),
        const Spacer(),
        _Keypad(onKey: _key, onSubmit: _submit, canSubmit: _entry.isNotEmpty),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: i < done ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i < done ? AppColors.primary : AppColors.stroke,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.onSubmit, required this.canSubmit});

  final ValueChanged<String> onKey;
  final VoidCallback onSubmit;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget key(String label, {VoidCallback? onTap, bool primary = false, IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Pressable(
          onTap: onTap ?? () => onKey(label),
          scale: 0.94,
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: icon == null ? label : (primary ? 'Check' : 'Delete'),
            child: Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary ? (canSubmit ? AppColors.primary : AppColors.surfaceHigh) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: primary ? null : Border.all(color: AppColors.stroke),
              ),
              child: icon != null
                  ? Icon(icon, color: primary ? Colors.white : AppColors.textSecondary)
                  : Text(label, style: text.titleLarge),
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) key(k)]),
        Row(
          children: [
            key('⌫', icon: Icons.backspace_outlined),
            key('0'),
            key('✓', onTap: onSubmit, primary: true, icon: Icons.check_rounded),
          ],
        ),
      ],
    );
  }
}
