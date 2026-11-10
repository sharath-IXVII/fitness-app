import '../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/beta_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/progress_ring.dart';
import 'domain/health.dart';
import 'domain/pulse_signal.dart';
import 'health_providers.dart';
import 'pulse_source.dart';
import 'widgets/health_widgets.dart';

enum _Stage { intro, measuring, done, unsteady, error }

/// Heart rate from the camera: a fingertip over the back camera and flash for
/// 30 seconds. An estimate, clearly labelled as one.
class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen> {
  _Stage _stage = _Stage.intro;
  PulseMeter _meter = PulseMeter();
  StreamSubscription<PulseSample>? _sub;
  PulseSource? _source;
  PulseResult? _result;
  String? _error;
  int _frames = 0;
  bool _saved = false;

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.measuring;
      _meter = PulseMeter();
      _result = null;
      _error = null;
      _saved = false;
      _frames = 0;
    });
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    final source = ref.read(pulseSourceProvider);
    _source = source;
    _sub = source.start().listen(
      (s) {
        _meter.add(s);
        _frames++;
        final r = _meter.result;
        if (r.status == PulseStatus.done || r.status == PulseStatus.unsteady) {
          _finish(r);
        } else if (_frames % 5 == 0 && mounted) {
          setState(() {});
        }
      },
      onError: (Object e) {
        _end();
        if (mounted) {
          setState(() {
            _stage = _Stage.error;
            _error = '$e';
          });
        }
      },
    );
  }

  void _finish(PulseResult r) {
    _end();
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _result = r;
      _stage = r.status == PulseStatus.done ? _Stage.done : _Stage.unsteady;
    });
  }

  /// Stops the camera and the flash.
  void _end() {
    _sub?.cancel();
    _sub = null;
    _source?.stop();
    _source = null;
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    _end();
    super.dispose();
  }

  Future<void> _save(int bpm) async {
    await ref
        .read(healthLogProvider.notifier)
        .add(HealthReading.single(kind: ReadingKind.pulse, at: DateTime.now(), value: bpm));
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Saved to your readings'))));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [Text(tr('Heart rate')), SizedBox(width: 10), BetaTag()]),
      ),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            switch (_stage) {
              _Stage.intro => _intro(text),
              _Stage.measuring => _measuring(text),
              _Stage.done => _done(text),
              _Stage.unsteady => _message(
                text,
                Icons.sensors_off_rounded,
                'We could not get a steady reading',
                'Rest for a few minutes, sit still, rest your hand on a table, and press only lightly. Then try '
                    'again.',
              ),
              _Stage.error => _message(text, Icons.error_outline_rounded, 'Could not start', _error ?? 'Try again.'),
            },
            const SizedBox(height: 18),
            Text(tr('This is an estimate from the camera and can be off by a few beats. It is not a medical measurement. '
              'For an accurate reading use a pulse oximeter or a smartwatch, and see a doctor if you feel unwell.'),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro(TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Measure your pulse in 30 seconds'), style: text.titleMedium),
            const SizedBox(height: 12),
            for (final (i, s) in const [
              'Sit down and rest for a minute. Stay still and quiet.',
              'Tap Start. The flash will light up.',
              'Cover the back camera and the flash together with your fingertip. Press lightly, do not squeeze.',
              'Hold still until the ring fills. The number appears at the end.',
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: text.labelSmall?.copyWith(color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      GradientButton(label: tr('Start'), icon: Icons.favorite_rounded, onPressed: _start),
    ],
  );

  Widget _measuring(TextTheme text) {
    final m = _meter;
    final live = m.live;
    final left = (m.seconds - m.validSeconds).ceil().clamp(0, 99);
    final status = !m.fingerOn
        ? 'Cover the camera and the flash with your fingertip'
        : m.validSeconds < 3
        ? 'Good. Hold still...'
        : '$left seconds to go. Hold still.';
    return Column(
      children: [
        const SizedBox(height: 12),
        ProgressRing(
          progress: m.progress,
          color: AppColors.primary,
          size: 190,
          stroke: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: AppColors.primary),
              Text(
                live != null && m.fingerOn ? '${live.bpm.round()}' : '--',
                style: text.displayMedium,
              ),
              Text(tr('bpm (estimating)'), style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(status, style: text.titleSmall, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        SizedBox(
          height: 64,
          width: double.infinity,
          child: CustomPaint(painter: WavePainter(m.recentValues(), AppColors.primary)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            _end();
            setState(() => _stage = _Stage.intro);
          },
          child: Text(tr('Cancel')),
        ),
      ],
    );
  }

  Widget _done(TextTheme text) {
    final bpm = _result!.bpm!;
    final rating = ratePulse(bpm);
    return Column(
      children: [
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.favorite_rounded, color: AppColors.primary, size: 28),
              Text('$bpm', style: text.displayLarge),
              Text(tr('beats per minute (about)'), style: text.bodySmall),
              const SizedBox(height: 12),
              RatingChip(rating: rating),
              const SizedBox(height: 10),
              Text(rating.advice, style: text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(tr('Judged as a resting pulse. If you had just moved, it will read higher.'),
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GradientButton(
          label: _saved ? 'Saved' : 'Save to my readings',
          icon: _saved ? Icons.check_rounded : Icons.bookmark_add_rounded,
          onPressed: _saved ? null : () => _save(bpm),
        ),
        TextButton(onPressed: _start, child: Text(tr('Measure again'))),
      ],
    );
  }

  Widget _message(TextTheme text, IconData icon, String title, String body) => Column(
    children: [
      const SizedBox(height: 16),
      Icon(icon, size: 44, color: AppColors.amber),
      const SizedBox(height: 10),
      Text(title, style: text.titleMedium, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text(body, style: text.bodyMedium, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      GradientButton(label: tr('Try again'), icon: Icons.refresh_rounded, onPressed: _start),
    ],
  );
}
