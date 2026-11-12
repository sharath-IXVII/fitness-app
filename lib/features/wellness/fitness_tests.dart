import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import 'wellness.dart';

Widget testPage(String title, Widget body) => PageBackground(
  child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
    body: SafeArea(child: body),
  ),
);

// ===================================================================== report

/// What a finished test shows: the result, what it means, how exact it is,
/// earlier results and tips.
class TestReport {
  const TestReport({
    required this.title,
    required this.value,
    required this.unit,
    required this.summary,
    required this.meaning,
    required this.accuracy,
    required this.tips,
    required this.kind,
    this.format,
  });

  final String title;
  final String value;
  final String unit;
  final String summary;
  final String meaning;
  final String accuracy;
  final List<String> tips;

  /// Wellness kind, for the history.
  final String kind;

  /// How a stored value is shown in the history.
  final String Function(WellnessEntry e)? format;
}

class TestReportScreen extends ConsumerWidget {
  const TestReportScreen({super.key, required this.report, required this.retake});

  final TestReport report;
  final Widget Function() retake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final history = [
      for (final e in ref.watch(wellnessProvider).reversed)
        if (e.kind == report.kind) e,
    ].take(6).toList();
    Widget section(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(body, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return testPage(
      tr('Your report'),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [AppColors.primary, Color.lerp(AppColors.primary, Colors.black, 0.3)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title.toUpperCase(),
                  style: text.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      report.value,
                      style: text.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Text(report.unit, style: text.titleMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(report.summary, style: text.bodyMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy, h:mm a').format(clock.now()),
                  style: text.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          section(Icons.insights_rounded, tr('What it means'), report.meaning),
          section(Icons.straighten_rounded, tr('How exact is this?'), report.accuracy),
          if (report.tips.isNotEmpty)
            section(Icons.tips_and_updates_outlined, tr('Tips'), report.tips.map((t) => '• $t').join('\n')),
          if (history.length > 1) ...[
            const SizedBox(height: 18),
            Text(tr('Your results'), style: text.titleMedium),
            const SizedBox(height: 6),
            for (final e in history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(report.format?.call(e) ?? '${e.value}'),
                trailing: Text(DateFormat('d MMM').format(e.at), style: text.bodySmall),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            tr('A general fitness reference for your own tracking, not a medical assessment.'),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => retake())),
                  child: Text(tr('Test again')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Done'))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showTestReport(BuildContext context, TestReport r, Widget Function() retake) => Navigator.of(context)
    .pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TestReportScreen(report: r, retake: retake),
      ),
    );

// ===================================================================== reaction

/// Reaction time: tap as soon as the screen turns green, five times.
class ReactionTestScreen extends ConsumerStatefulWidget {
  const ReactionTestScreen({super.key, this.random});

  final math.Random? random;

  @override
  ConsumerState<ReactionTestScreen> createState() => _ReactionTestScreenState();
}

enum _RState { idle, waiting, go, early }

class _ReactionTestScreenState extends ConsumerState<ReactionTestScreen> {
  static const rounds = 5;
  late final _rng = widget.random ?? math.Random();
  final _times = <int>[];
  _RState _state = _RState.idle;
  Timer? _timer;
  DateTime? _shown;

  void _arm() {
    setState(() => _state = _RState.waiting);
    _timer = Timer(Duration(milliseconds: 1500 + _rng.nextInt(2500)), () {
      setState(() {
        _state = _RState.go;
        _shown = clock.now();
      });
    });
  }

  void _tap() {
    switch (_state) {
      case _RState.idle || _RState.early:
        _arm();
      case _RState.waiting:
        _timer?.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _state = _RState.early);
      case _RState.go:
        HapticFeedback.lightImpact();
        _times.add(clock.now().difference(_shown!).inMilliseconds);
        if (_times.length >= rounds) {
          _done();
        } else {
          _arm();
        }
    }
  }

  void _done() {
    final sorted = [..._times]..sort();
    final avg = (_times.reduce((a, b) => a + b) / _times.length).round();
    ref.read(wellnessProvider.notifier).add('reaction', avg, extra: sorted.first);
    final band = avg < 250
        ? tr('Quick. Faster than most people.')
        : avg < 350
        ? tr('Typical. Most people tap in 250–350 ms.')
        : tr('A bit slower than typical. Sleep, focus and practice all help.');
    showTestReport(
      context,
      TestReport(
        title: tr('Reaction time'),
        value: '$avg',
        unit: 'ms',
        summary: '${tr('Best')}: ${sorted.first} ms · $rounds ${tr('taps')}',
        meaning: band,
        accuracy: tr(
          'Phone screens and touch add about 20–60 ms, so compare your results on the same phone. The average of five taps is steadier than one.',
        ),
        tips: [
          tr('Test at the same time of day to see trends.'),
          tr('Tiredness and screen brightness change the result.'),
        ],
        kind: 'reaction',
        format: (e) => '${e.value} ms (${tr('best')} ${e.extra} ms)',
      ),
      () => const ReactionTestScreen(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (color, label) = switch (_state) {
      _RState.idle => (AppColors.primary, tr('Tap to start')),
      _RState.waiting => (const Color(0xFFC0392B), tr('Wait for green…')),
      _RState.go => (const Color(0xFF2E8B57), tr('TAP!')),
      _RState.early => (const Color(0xFFD9A100), tr('Too soon! Tap to try again')),
    };
    return testPage(
      tr('Reaction time'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            Text(tr('Tap the box the moment it turns green. Five rounds.'), style: text.bodyMedium),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => _tap(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28)),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: text.headlineSmall?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text('${_times.length} / $rounds', style: text.titleMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
