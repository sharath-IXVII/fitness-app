import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import 'wellness.dart';

Widget _scaffold(BuildContext context, String title, Widget body) => Scaffold(
  backgroundColor: Colors.transparent,
  appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
  body: PageBackground(child: SafeArea(child: body)),
);

// ---------------------------------------------------------------- breathing

/// Guided breathing: the circle grows as you breathe in and shrinks as you
/// breathe out.
class BreathingScreen extends ConsumerStatefulWidget {
  const BreathingScreen({super.key});

  @override
  ConsumerState<BreathingScreen> createState() => _BreathingScreenState();
}

enum BreathPattern {
  box('Box breathing', 'In 4 · hold 4 · out 4 · hold 4', [4, 4, 4, 4]),
  calm('Calm', 'In 4 · hold 7 · out 8', [4, 7, 8, 0]),
  easy('Easy', 'In 5 · out 5', [5, 0, 5, 0]);

  const BreathPattern(this.label, this.steps, this.seconds);

  final String label;
  final String steps;

  /// In, hold, out, hold.
  final List<int> seconds;
  int get cycle => seconds.fold(0, (a, b) => a + b);
}

class _BreathingScreenState extends ConsumerState<BreathingScreen> with SingleTickerProviderStateMixin {
  BreathPattern _pattern = BreathPattern.box;
  int _minutes = 2;
  Timer? _timer;
  double _elapsed = 0;

  bool get _running => _timer != null;

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() => _elapsed = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _elapsed += 0.05);
      if (_elapsed >= _minutes * 60) _finish(done: true);
    });
  }

  Future<void> _finish({bool done = false}) async {
    _timer?.cancel();
    _timer = null;
    final mins = done ? _minutes : (_elapsed / 60).floor();
    setState(() {});
    if (mins > 0) {
      await ref.read(wellnessProvider.notifier).add('breathe', mins);
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('Nice. Calm minutes logged')}: $mins')));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Phase label and circle size (0–1) at [t] seconds.
  (String, double) _phase(double t) {
    final s = _pattern.seconds;
    var x = t % _pattern.cycle;
    if (x < s[0]) return (tr('Breathe in'), x / s[0]);
    x -= s[0];
    if (x < s[1]) return (tr('Hold'), 1);
    x -= s[1];
    if (x < s[2]) return (tr('Breathe out'), 1 - x / s[2]);
    return (tr('Hold'), 0);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final week = ref.watch(calmMinutesWeekProvider);
    final (label, size) = _running ? _phase(_elapsed) : (tr('Ready'), 0.35);
    final left = (_minutes * 60 - _elapsed).clamp(0, 9999).round();
    return _scaffold(
      context,
      tr('Breathe'),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(tr('A few slow breaths can help you relax and focus.'), style: text.bodyMedium),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 120 + 150 * size,
                height: 120 + 150 * size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.55), AppColors.primary.withValues(alpha: 0.15)],
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 40)],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: text.titleLarge?.copyWith(color: Colors.white)),
                    if (_running)
                      Text(
                        '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                        style: text.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_running) ...[
            for (final p in BreathPattern.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoiceChip(
                  selected: _pattern == p,
                  onSelected: (_) => setState(() => _pattern = p),
                  label: SizedBox(width: double.infinity, child: Text('${tr(p.label)}  ·  ${tr(p.steps)}')),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in [1, 2, 3, 5, 10])
                  ChoiceChip(
                    label: Text('$m ${tr('min')}'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            GradientButton(label: tr('Start'), icon: Icons.air_rounded, onPressed: _start),
          ] else
            OutlinedButton(onPressed: _finish, child: Text(tr('Stop'))),
          const SizedBox(height: 18),
          Text('${tr('Calm minutes this week')}: $week', style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- breathing rate

/// Breathing rate: sit still, tap each time you breathe in, for a minute.
class BreathingRateScreen extends ConsumerStatefulWidget {
  const BreathingRateScreen({super.key});

  @override
  ConsumerState<BreathingRateScreen> createState() => _BreathingRateScreenState();
}

class _BreathingRateScreenState extends ConsumerState<BreathingRateScreen> {
  static const _length = 60;
  final _taps = <double>[];
  DateTime? _start;
  Timer? _timer;
  int? _result;

  double get _secs => _start == null ? 0 : clock.now().difference(_start!).inMilliseconds / 1000;

  void _tap() {
    HapticFeedback.selectionClick();
    if (_start == null) {
      _start = clock.now();
      _taps.clear();
      _result = null;
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_secs >= _length) _done();
        setState(() {});
      });
    }
    setState(() => _taps.add(_secs));
  }

  Future<void> _done() async {
    _timer?.cancel();
    _timer = null;
    _start = null;
    final r = breathsPerMinute(_taps);
    setState(() => _result = r);
    if (r != null) await ref.read(wellnessProvider.notifier).add('rate', r);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final history = [
      for (final e in ref.watch(wellnessProvider).reversed)
        if (e.kind == 'rate') e,
    ].take(7).toList();
    final running = _start != null;
    return _scaffold(
      context,
      tr('Breathing rate'),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            tr('Sit still and breathe normally. Tap the circle each time you breathe in, for one minute.'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _tap,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: running ? 0.85 : 0.65),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 30)],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      running ? '${_taps.length}' : (_result != null ? '$_result' : tr('Tap')),
                      style: text.displaySmall?.copyWith(color: Colors.white),
                    ),
                    Text(
                      running
                          ? '${(_length - _secs).clamp(0, _length).round()} ${tr('s left')}'
                          : (_result != null ? tr('breaths a minute') : tr('to start')),
                      style: text.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!running && _taps.isNotEmpty && _result == null)
            Text(tr('Too few taps to count. Try again.'), style: text.bodySmall, textAlign: TextAlign.center),
          if (running) OutlinedButton(onPressed: _done, child: Text(tr('Finish now'))),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              tr(
                'For your own tracking, not a medical measurement. Compare your own readings over time, taken the same way.',
              ),
              style: text.bodySmall,
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(tr('Recent'), style: text.titleMedium),
            for (final e in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${e.value} ${tr('breaths a minute')}'),
                subtitle: Text(DateFormat('d MMM, h:mm a').format(e.at)),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- mood

const _moods = ['😣', '😕', '😐', '🙂', '😄'];

/// Mood and energy check-in, with the last 7 days.
class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  int? _mood;
  int _energy = 3;

  Future<void> _save() async {
    if (_mood == null) return;
    await ref.read(wellnessProvider.notifier).add('mood', _mood!, extra: _energy);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Check-in saved.'))));
      setState(() => _mood = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(wellnessProvider);
    final today = clock.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    WellnessEntry? lastOn(DateTime d) => [
      for (final e in all)
        if (e.kind == 'mood' && e.at.year == d.year && e.at.month == d.month && e.at.day == d.day) e,
    ].lastOrNull;
    return _scaffold(
      context,
      tr('Mood & energy'),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(tr('How are you feeling right now?'), style: text.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _mood = i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _mood == i + 1 ? AppColors.primarySoft : Colors.transparent,
                      border: Border.all(color: _mood == i + 1 ? AppColors.primary : Colors.transparent, width: 2),
                    ),
                    child: Text(_moods[i], style: const TextStyle(fontSize: 34)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('${tr('Energy')}: $_energy / 5', style: text.titleMedium),
          Slider(
            value: _energy.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) => setState(() => _energy = v.round()),
          ),
          const SizedBox(height: 8),
          GradientButton(
            label: tr('Save check-in'),
            icon: Icons.check_rounded,
            onPressed: _mood == null ? null : _save,
          ),
          const SizedBox(height: 26),
          Text(tr('Last 7 days'), style: text.titleMedium),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days)
                  Column(
                    children: [
                      Text(
                        lastOn(d) == null ? '·' : _moods[(lastOn(d)!.value - 1).clamp(0, 4)],
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 40,
                        width: 10,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: lastOn(d) == null ? 2 : 8.0 * lastOn(d)!.extra,
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(DateFormat.E().format(d).substring(0, 1), style: text.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(tr('Bars show your energy.'), style: text.bodySmall),
        ],
      ),
    );
  }
}
