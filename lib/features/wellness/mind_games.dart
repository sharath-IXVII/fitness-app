import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import 'fitness_tests.dart';
import 'wellness.dart';

/// Best earlier result of [kind]: highest, or lowest when [lowerIsBetter].
int? bestOf(List<WellnessEntry> all, String kind, {bool lowerIsBetter = false}) {
  final v = [
    for (final e in all)
      if (e.kind == kind) e.value,
  ];
  if (v.isEmpty) return null;
  return lowerIsBetter ? v.reduce(math.min) : v.reduce(math.max);
}

String _bestLine(int score, int? before, {bool lowerIsBetter = false, String unit = ''}) {
  if (before == null) return tr('First game: this is your best.');
  final better = lowerIsBetter ? score < before : score > before;
  return better ? '${tr('New personal best!')} (${tr('was')} $before$unit)' : '${tr('Your best')}: $before$unit';
}

Widget _intro(BuildContext context, String text, VoidCallback onStart) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GradientButton(label: tr('Start'), icon: Icons.play_arrow_rounded, onPressed: onStart),
      ],
    ),
  ),
);

// ===================================================================== memory

/// Memory: tiles light up in a sequence; tap them back in the same order.
/// Each round adds one more.
class MemoryGameScreen extends ConsumerStatefulWidget {
  const MemoryGameScreen({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends ConsumerState<MemoryGameScreen> {
  late final _rng = widget.random ?? math.Random();
  final _seq = <int>[];
  int _input = 0;
  int? _lit;
  bool _showing = false;
  bool _started = false;
  void _next() {
    _seq.add(_rng.nextInt(9));
    _input = 0;
    _play();
  }

  /// Lights each tile in turn: on for 450 ms, off for 200 ms.
  Future<void> _play() async {
    setState(() => _showing = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (final k in List.of(_seq)) {
      if (!mounted) return;
      setState(() => _lit = k);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _lit = null);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) setState(() => _showing = false);
  }

  void _tap(int k) {
    if (_showing) return;
    HapticFeedback.selectionClick();
    setState(() => _lit = k);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _lit == k) setState(() => _lit = null);
    });
    if (_seq[_input] != k) {
      HapticFeedback.heavyImpact();
      _over();
      return;
    }
    if (++_input == _seq.length) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _next();
      });
    }
  }

  void _over() {
    final score = _seq.length - 1;
    final before = bestOf(ref.read(wellnessProvider), 'memory');
    ref.read(wellnessProvider.notifier).add('memory', score);
    showTestReport(
      context,
      TestReport(
        title: tr('Memory'),
        value: '$score',
        unit: score == 1 ? tr('tile') : tr('tiles'),
        summary: _bestLine(score, before),
        meaning: score >= 9
            ? tr('Excellent memory span. Most people remember about 5–7 items.')
            : score >= 5
            ? tr('Right where most people are: about 5–7 items.')
            : tr('A warm-up score. Memory span grows quickly with practice and good sleep.'),
        accuracy: tr('Your score is the longest sequence you repeated without a mistake.'),
        tips: [tr('Say the positions to yourself as they light up.'), tr('Group them into chunks of three.')],
        kind: 'memory',
        format: (e) => '${e.value} ${tr('tiles')}',
      ),
      () => const MemoryGameScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return testPage(
      tr('Memory'),
      !_started
          ? _intro(
              context,
              tr('Watch the tiles light up, then tap them in the same order. Each round adds one more.'),
              () {
                setState(() => _started = true);
                for (var i = 0; i < 2; i++) {
                  _seq.add(_rng.nextInt(9));
                }
                _next();
              },
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(_showing ? tr('Watch…') : tr('Your turn'), style: text.titleLarge),
                  Text('${tr('Round')} ${_seq.length - 2} · ${_seq.length} ${tr('tiles')}', style: text.bodySmall),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: 1,
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var k = 0; k < 9; k++)
                          GestureDetector(
                            key: ValueKey('tile$k'),
                            onTapDown: (_) => _tap(k),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: _lit == k ? AppColors.primary : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: _lit == k
                                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 18)]
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ===================================================================== focus

/// Focus: tap 1 to 25 in order on a shuffled grid, as fast as you can.
class FocusGameScreen extends ConsumerStatefulWidget {
  const FocusGameScreen({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<FocusGameScreen> createState() => _FocusGameScreenState();
}

class _FocusGameScreenState extends ConsumerState<FocusGameScreen> {
  late final List<int> _grid = [for (var i = 1; i <= 25; i++) i]..shuffle(widget.random ?? math.Random());
  int _next = 1;
  int _misses = 0;
  DateTime? _start;
  Timer? _tick;
  int? _wrong;

  void _tap(int n) {
    _start ??= clock.now();
    _tick ??= Timer.periodic(const Duration(milliseconds: 100), (_) => setState(() {}));
    if (n != _next) {
      HapticFeedback.heavyImpact();
      setState(() {
        _misses++;
        _wrong = n;
      });
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _next++;
      _wrong = null;
    });
    if (_next > 25) _done();
  }

  double get _secs => _start == null ? 0 : clock.now().difference(_start!).inMilliseconds / 1000;

  void _done() {
    _tick?.cancel();
    final secs = _secs + _misses; // a second added for every wrong tap
    final tenths = (secs * 10).round();
    final before = bestOf(ref.read(wellnessProvider), 'focus', lowerIsBetter: true);
    ref.read(wellnessProvider.notifier).add('focus', tenths, extra: _misses);
    String s(int t) => (t / 10).toStringAsFixed(1);
    showTestReport(
      context,
      TestReport(
        title: tr('Focus'),
        value: s(tenths),
        unit: tr('seconds'),
        summary: before == null
            ? tr('First game: this is your best.')
            : tenths < before
            ? '${tr('New personal best!')} (${tr('was')} ${s(before)} s)'
            : '${tr('Your best')}: ${s(before)} s',
        meaning: secs < 20
            ? tr('Sharp focus. Under 20 seconds is very quick.')
            : secs < 35
            ? tr('Good focus. Many people take 20–35 seconds.')
            : tr('Keep at it: most people get much faster within a few games.'),
        accuracy: '${tr('Time from your first tap to 25, plus 1 second for each wrong tap')} ($_misses).',
        tips: [
          tr('Keep your eyes in the middle and spot numbers from the side.'),
          tr('Find the next number before you tap.'),
        ],
        kind: 'focus',
        format: (e) => '${s(e.value)} s',
      ),
      () => const FocusGameScreen(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return testPage(
      tr('Focus'),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(tr('Tap 1 to 25 in order, as fast as you can.'), style: text.bodyMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${tr('Next')}: ${_next > 25 ? '✓' : _next}', style: text.titleLarge),
                Text('${_secs.toStringAsFixed(1)} s', style: text.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.count(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final n in _grid)
                    GestureDetector(
                      onTapDown: (_) => _tap(n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color: n < _next
                              ? AppColors.primarySoft.withValues(alpha: 0.4)
                              : _wrong == n
                              ? const Color(0xFFFADBD8)
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$n',
                          style: text.titleLarge?.copyWith(
                            color: n < _next ? AppColors.textMuted : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== colour clash

const _inks = [
  ('RED', Color(0xFFD64541)),
  ('BLUE', Color(0xFF2E7DD7)),
  ('GREEN', Color(0xFF2E9E5B)),
  ('YELLOW', Color(0xFFE0A800)),
];

/// Colour clash: a colour word in a different ink. Tap the ink colour, not
/// the word. 30 seconds.
class ColourGameScreen extends ConsumerStatefulWidget {
  const ColourGameScreen({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<ColourGameScreen> createState() => _ColourGameScreenState();
}

class _ColourGameScreenState extends ConsumerState<ColourGameScreen> {
  static const length = 30;
  late final _rng = widget.random ?? math.Random();
  int _word = 0, _ink = 1;
  int _right = 0, _wrong = 0;
  DateTime? _start;
  Timer? _tick;
  bool _flash = false;

  void _deal() {
    _word = _rng.nextInt(4);
    // Mostly a clash; sometimes the same, so you can't just pick "not the word".
    _ink = _rng.nextDouble() < 0.25 ? _word : (_word + 1 + _rng.nextInt(3)) % 4;
  }

  void _begin() {
    setState(() {
      _start = clock.now();
      _deal();
    });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_left <= 0) {
        _done();
      } else {
        setState(() {});
      }
    });
  }

  double get _left =>
      _start == null ? length.toDouble() : length - clock.now().difference(_start!).inMilliseconds / 1000;

  void _answer(int k) {
    if (_start == null || _left <= 0) return;
    final ok = k == _ink;
    ok ? HapticFeedback.selectionClick() : HapticFeedback.heavyImpact();
    setState(() {
      ok ? _right++ : _wrong++;
      _flash = !ok;
      _deal();
    });
  }

  void _done() {
    _tick?.cancel();
    final score = math.max(0, _right - _wrong);
    final before = bestOf(ref.read(wellnessProvider), 'colour');
    ref.read(wellnessProvider.notifier).add('colour', score, extra: _wrong);
    final total = _right + _wrong;
    showTestReport(
      context,
      TestReport(
        title: tr('Colour clash'),
        value: '$score',
        unit: tr('points'),
        summary: _bestLine(score, before),
        meaning:
            '$_right ${tr('right')}, $_wrong ${tr('wrong')}'
            '${total == 0 ? '' : ' (${(100 * _right / total).round()}%)'}. '
            '${score >= 25
                ? tr('A very quick, focused mind.')
                : score >= 15
                ? tr('Good control: your brain wants to read the word, and you held it back.')
                : tr('This one is hard at first. Most people improve fast with practice.')}',
        accuracy: tr('Points are right answers minus wrong answers in 30 seconds.'),
        tips: [
          tr('Look at the colour, not the letters.'),
          tr('Speed comes after accuracy: aim for no mistakes first.'),
        ],
        kind: 'colour',
        format: (e) => '${e.value} ${tr('points')}',
      ),
      () => const ColourGameScreen(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return testPage(
      tr('Colour clash'),
      _start == null
          ? _intro(
              context,
              tr(
                'Tap the colour of the ink, not the word. For example, BLUE written in red: tap Red. You have 30 seconds.',
              ),
              _begin,
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${tr('Points')}: ${math.max(0, _right - _wrong)}', style: text.titleLarge),
                      Text('${_left.clamp(0, length).ceil()} s', style: text.titleLarge),
                    ],
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _flash ? const Color(0xFFFADBD8) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tr(_inks[_word].$1),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: _inks[_ink].$2,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var k = 0; k < 4; k++)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _inks[k].$2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _answer(k),
                          child: Text(
                            tr(['Red', 'Blue', 'Green', 'Yellow'][k]),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
