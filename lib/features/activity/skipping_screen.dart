import '../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../clubs/domain/club_challenge.dart' show formatDuration;
import '../share/share_card.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/skip_counter.dart';

/// Readings of user acceleration (x, y, z, time). Overridden in tests.
final skipSensorProvider = Provider<Stream<(double, double, double, DateTime)>>(
  (ref) =>
      userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .map((e) => (e.x, e.y, e.z, DateTime.now())),
);

/// Rope skipping, counted by the phone's motion sensor. No GPS, no camera.
class SkippingScreen extends ConsumerStatefulWidget {
  const SkippingScreen({super.key});

  @override
  ConsumerState<SkippingScreen> createState() => _SkippingScreenState();
}

class _SkippingScreenState extends ConsumerState<SkippingScreen> {
  SkipCounter _counter = SkipCounter();
  StreamSubscription<(double, double, double, DateTime)>? _sub;
  Timer? _tick;
  DateTime? _startedAt;
  bool _running = false;
  int _target = 200;

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.heavyImpact();
    _counter = SkipCounter();
    _startedAt = clock.now();
    _sub = ref.read(skipSensorProvider).listen((e) {
      if (_counter.add(e.$1, e.$2, e.$3, e.$4) && mounted) {
        setState(() {});
        if (_counter.count == _target) HapticFeedback.heavyImpact();
      }
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() => _running = true);
  }

  Future<void> _stop() async {
    // Stop at once; the sensor shuts down in the background.
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
    _tick?.cancel();
    final secs = clock.now().difference(_startedAt!).inSeconds;
    final count = _counter.count;
    setState(() => _running = false);
    // 200 skips or 5 minutes counts as today's workout.
    if (count >= 200 || secs >= 300) {
      await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(workoutDone: true));
    }
    if (!mounted || count == 0) return;
    final share = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('$count skips! 🎉'),
        content: Text('In ${formatDuration(secs * 1000)}. About ${(count * 0.12).round()} kcal.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(tr('Done'))),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(tr('Share'))),
        ],
      ),
    );
    if (share == true && mounted) {
      context.push(
        Routes.shareCard,
        extra: ShareCardData(
          symbol: '🪢',
          headline: '$count skips',
          subtitle: tr('Rope skipping on FittArc'),
          stats: [(formatDuration(secs * 1000), 'Time'), ('${(count * 0.12).round()}', 'kcal')],
          shareText: '$count skips today on FittArc 🪢 fittarc.in',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final secs = _startedAt == null || !_running ? 0 : clock.now().difference(_startedAt!).inSeconds;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Skipping'))),
      body: PageBackground(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(tr('Keep your phone in a pocket (or hold it) and skip. FittArc counts each jump.'),
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (_counter.count / _target).clamp(0.0, 1.0),
                      strokeWidth: 14,
                      backgroundColor: AppColors.surfaceHigh,
                      color: AppColors.primary,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_counter.count}', style: text.displayLarge),
                          Text('of $_target skips', style: text.bodyLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(formatDuration(secs * 1000), style: text.titleLarge),
              const Spacer(),
              if (!_running) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in const [50, 100, 200, 500])
                      ChoiceChip(
                        label: Text('$t'),
                        selected: _target == t,
                        onSelected: (_) => setState(() => _target = t),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GradientButton(label: tr('Start'), icon: Icons.play_arrow_rounded, onPressed: _start),
              ] else
                GradientButton(label: tr('Stop'), icon: Icons.stop_rounded, onPressed: _stop),
            ],
          ),
        ),
      ),
    );
  }
}
