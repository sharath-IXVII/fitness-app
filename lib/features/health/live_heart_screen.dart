import '../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/beta_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../profile/profile_providers.dart';
import 'domain/live_hr.dart';
import 'health_providers.dart';
import 'hr_source.dart';

Color zoneColor(HrZone z) => switch (z) {
  HrZone.rest => const Color(0xFF8A94A6),
  HrZone.warm => const Color(0xFF2F7DBE),
  HrZone.steady => const Color(0xFF2E8B57),
  HrZone.push => const Color(0xFFE0A100),
  HrZone.peak => const Color(0xFFD9432B),
};

enum _Stage { scan, connecting, live, summary, error }

/// Live heart rate from a Bluetooth watch or chest strap. While it runs, time
/// in each zone turns into Arc minutes.
class LiveHeartScreen extends ConsumerStatefulWidget {
  const LiveHeartScreen({super.key});

  @override
  ConsumerState<LiveHeartScreen> createState() => _LiveHeartScreenState();
}

class _LiveHeartScreenState extends ConsumerState<LiveHeartScreen> {
  _Stage _stage = _Stage.scan;
  List<HrDevice> _found = const [];
  StreamSubscription<List<HrDevice>>? _scanSub;
  StreamSubscription<dynamic>? _liveSub;
  HrSource? _source;
  HrSession? _session;
  bool _contactLost = false;
  DateTime? _startedAt;
  String? _error;
  double _earned = 0;

  int get _max => maxHeartRate(ref.read(profileProvider)?.age ?? 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  void _scan() {
    _source = ref.read(hrSourceProvider);
    setState(() {
      _stage = _Stage.scan;
      _found = const [];
      _error = null;
    });
    _scanSub?.cancel();
    _scanSub = _source!.scan().listen(
      (list) {
        if (mounted) setState(() => _found = list);
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _stage = _Stage.error;
            _error = e is StateError ? e.message : 'Could not look for devices.';
          });
        }
      },
    );
  }

  void _connect(HrDevice d) {
    _scanSub?.cancel();
    _scanSub = null;
    final source = ref.read(hrSourceProvider);
    _source = source;
    setState(() {
      _stage = _Stage.connecting;
      _session = HrSession(maxBpm: _max);
      _contactLost = false;
      _startedAt = null;
    });
    // Keeps the screen on during a workout; never waited for.
    unawaited(WakelockPlus.enable().catchError((_) {}));
    _liveSub = source
        .connect(d.id)
        .listen(
          (m) {
            if (!mounted) return;
            _startedAt ??= clock.now();
            setState(() {
              _stage = _Stage.live;
              _contactLost = m.contactLost;
              if (!m.contactLost && m.bpm > 0) _session!.add(m.bpm, clock.now());
            });
          },
          onError: (Object e) {
            _stopLink();
            if (mounted) {
              setState(() {
                _stage = _Stage.error;
                _error = e is StateError ? e.message : 'The watch disconnected.';
              });
            }
          },
          onDone: () {
            // The watch went out of range or switched off: keep what was earned.
            _stopLink();
            if (mounted && _stage == _Stage.live) _finish(lost: true);
          },
        );
  }

  void _stopLink() {
    _liveSub?.cancel();
    _liveSub = null;
    _source?.disconnect();
    unawaited(WakelockPlus.disable().catchError((_) {}));
  }

  Future<void> _finish({bool lost = false}) async {
    _stopLink();
    final s = _session;
    final arc = s == null ? 0.0 : s.arcMinutes;
    if (arc > 0) await ref.read(arcMinutesProvider.notifier).add(clock.now(), arc);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _earned = arc;
      _stage = _Stage.summary;
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _source?.stopScan();
    _stopLink();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(tr('Live heart rate')), SizedBox(width: 10), BetaTag()],
        ),
      ),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            switch (_stage) {
              _Stage.scan => _scanView(text),
              _Stage.connecting => _busy(text, 'Connecting...', 'Keep the watch close to the phone.'),
              _Stage.live => _liveView(text),
              _Stage.summary => _summary(text),
              _Stage.error => _error_(text),
            },
          ],
        ),
      ),
    );
  }

  Widget _scanView(TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Connect a watch or chest strap'), style: text.titleMedium),
            const SizedBox(height: 10),
            for (final s in const [
              'Turn Bluetooth on.',
              'On the watch, start a workout or turn on "heart rate sharing" (also called broadcast). Chest straps '
                  'just need to be worn.',
              'Pick it from the list below.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: text.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(tr('Not every watch can share its heart rate this way. If yours does not show up, use Health Connect '
              'instead.'),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(_found.isEmpty ? 'Looking for devices...' : 'Tap your device', style: text.titleSmall),
        ],
      ),
      const SizedBox(height: 10),
      for (final d in _found)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pressable(
            onTap: () => _connect(d),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.watch_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.name.isEmpty ? 'Heart-rate device' : d.name,
                      style: text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    d.rssi > -60
                        ? 'Very close'
                        : d.rssi > -80
                        ? 'Close'
                        : 'Far',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 6),
      TextButton(onPressed: _scan, child: Text(tr('Search again'))),
    ],
  );

  Widget _busy(TextTheme text, String title, String body) => Column(
    children: [
      const SizedBox(height: 40),
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text(title, style: text.titleMedium),
      Text(body, style: text.bodySmall, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () {
          _stopLink();
          _scan();
        },
        child: Text(tr('Cancel')),
      ),
    ],
  );

  Widget _liveView(TextTheme text) {
    final s = _session!;
    final zone = s.zone ?? HrZone.rest;
    final color = zoneColor(zone);
    final elapsed = _startedAt == null ? Duration.zero : clock.now().difference(_startedAt!);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        const SizedBox(height: 8),
        ProgressRing(
          progress: ((s.current ?? 0) / s.maxBpm).clamp(0, 1),
          color: color,
          size: 210,
          stroke: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: color),
              Text(_contactLost ? '--' : '${s.current ?? '--'}', style: text.displayLarge),
              Text(tr('bpm'), style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
          child: Text(
            _contactLost ? 'Wear the sensor snugly' : zone.label,
            style: text.titleSmall?.copyWith(color: color),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(text, '$mm:$ss', 'Time'),
                  _stat(text, s.arcMinutes.toStringAsFixed(1), 'Arc minutes'),
                  _stat(text, s.top == 0 ? '--' : '${s.top}', 'Highest'),
                ],
              ),
              const SizedBox(height: 14),
              _ZoneBar(session: s),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GradientButton(label: tr('Finish'), icon: Icons.flag_rounded, onPressed: _finish),
        const SizedBox(height: 8),
        Text(tr('Moderate minutes count once and hard minutes count twice. Your top rate is estimated from your age.'),
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _stat(TextTheme text, String value, String label) => Column(
    children: [
      Text(value, style: text.titleLarge),
      Text(label, style: text.bodySmall),
    ],
  );

  Widget _summary(TextTheme text) {
    final s = _session!;
    final week = ref.watch(weekArcProvider);
    return Column(
      children: [
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 30),
              const SizedBox(height: 4),
              Text(_earned.toStringAsFixed(1), style: text.displayLarge),
              Text(tr('Arc minutes earned'), style: text.bodySmall),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(text, s.average == 0 ? '--' : '${s.average}', 'Average'),
                  _stat(text, s.top == 0 ? '--' : '${s.top}', 'Highest'),
                  _stat(text, '${(s.seconds / 60).round()} min', 'Tracked'),
                ],
              ),
              const SizedBox(height: 14),
              _ZoneBar(session: s),
              const SizedBox(height: 14),
              Text('${week.toStringAsFixed(0)} of $weeklyArcGoal this week', style: text.titleSmall),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GradientButton(label: tr('Done'), icon: Icons.check_rounded, onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }

  Widget _error_(TextTheme text) => Column(
    children: [
      const SizedBox(height: 16),
      Icon(Icons.bluetooth_disabled_rounded, size: 44, color: AppColors.amber),
      const SizedBox(height: 10),
      Text(tr('Could not connect'), style: text.titleMedium),
      const SizedBox(height: 6),
      Text(_error ?? 'Try again.', style: text.bodyMedium, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      GradientButton(label: tr('Try again'), icon: Icons.refresh_rounded, onPressed: _scan),
    ],
  );
}

/// How the session's time splits across the zones.
class _ZoneBar extends StatelessWidget {
  const _ZoneBar({required this.session});

  final HrSession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = session.seconds <= 0 ? 1.0 : session.seconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final z in HrZone.values)
                  Expanded(
                    flex: (session.secondsIn(z) / total * 1000).round().clamp(session.seconds <= 0 ? 1 : 0, 1000),
                    child: ColoredBox(color: zoneColor(z)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final z in HrZone.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: zoneColor(z), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('${z.label} ${(session.secondsIn(z) / 60).toStringAsFixed(1)}m', style: text.labelSmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
