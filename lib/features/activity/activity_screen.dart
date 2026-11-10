import '../../core/i18n/i18n.dart';
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../clubs/domain/club_challenge.dart';
import '../clubs/domain/run_report.dart';
import '../clubs/gps.dart';
import '../clubs/widgets/route_map.dart';
import '../streaks/daily_log_providers.dart';
import 'activity_providers.dart';
import 'domain/activity_session.dart';

enum _Phase { checking, ready, running, paused, done }

/// A run, walk or ride on your own: GPS on, go, see the route on the map;
/// pause any time; Finish saves it.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, required this.kind});

  final ActivityKind kind;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _Phase _phase = _Phase.checking;
  String? _problem;
  double? _accuracy;
  StreamSubscription<GpsFix>? _sub;
  Timer? _tick;

  /// Finished stretches (before pauses) and the current one.
  final List<RouteTracker> _parts = [];
  RouteTracker? _part;
  final List<(double, double)> _route = [];

  /// Moving time before the current stretch, and when it began.
  int _movedMs = 0;
  DateTime? _since;
  DateTime? _startedAt;

  static const _goodEnough = 20.0;

  ActivityKind get kind => widget.kind;

  double get _meters => _parts.fold(0.0, (a, p) => a + p.meters) + (_part?.meters ?? 0);
  int get _movingMs => _movedMs + (_since == null ? 0 : clock.now().difference(_since!).inMilliseconds);

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _phase = _Phase.checking;
      _problem = null;
    });
    final problem = await ref.read(gpsProvider).ensure();
    if (!mounted) return;
    setState(() {
      _problem = problem;
      _phase = _Phase.ready;
    });
    if (problem == null) {
      _sub ??= ref.read(gpsProvider).track().listen(_onFix, onError: (_) {});
    }
  }

  void _onFix(GpsFix f) {
    if (!mounted) return;
    _accuracy = f.accuracy;
    if (_phase == _Phase.running && _part != null) {
      if (_part!.add(f)) _route.add(_part!.route.last.point);
    }
    setState(() {});
  }

  void _start() {
    HapticFeedback.heavyImpact();
    _startedAt ??= clock.now();
    _part = RouteTracker(kind);
    _since = clock.now();
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() => _phase = _Phase.running);
  }

  void _pause() {
    HapticFeedback.mediumImpact();
    _movedMs = _movingMs;
    _since = null;
    if (_part != null) _parts.add(_part!);
    _part = null;
    setState(() => _phase = _Phase.paused);
  }

  Future<void> _finish() async {
    if (_phase == _Phase.running) _pause();
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
    _tick?.cancel();
    final splits = <int>[];
    // Km splits across stretches (moving time).
    var before = 0.0, offset = 0;
    for (final p in _parts) {
      for (final s in p.splitsMs) {
        final km = (splits.length + 1) * 1000;
        if (km > before) splits.add(offset + s);
      }
      before += p.meters;
      offset += p.spanMs;
    }
    final s = ActivitySession(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      kind: kind,
      startedAt: _startedAt ?? clock.now(),
      movingMs: _movedMs,
      distanceM: _meters.round(),
      route: simplifyRoute([for (final p in _route) GpsFix(p.$1, p.$2, 5, DateTime(2026))]),
      splitsMs: splits,
    );
    if (s.distanceM >= 50) {
      await ref.read(activitiesProvider.notifier).add(s);
      // Ten minutes on the move counts as today's workout.
      if (s.movingMs >= 10 * 60 * 1000) {
        await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(workoutDone: true));
      }
    }
    if (!mounted) return;
    if (s.distanceM < 50) {
      Navigator.of(context).pop();
      return;
    }
    context.pushReplacement(Routes.activitySummary, extra: s);
  }

  Future<void> _confirmFinish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Finish?')),
        content: Text('${formatKm(_meters.round())} in ${formatDuration(_movingMs)}. Save it?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(tr('Keep going'))),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: Text(tr('Finish'))),
        ],
      ),
    );
    if (ok == true) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = _phase == _Phase.running || _phase == _Phase.paused;
    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _confirmFinish();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(kind.label)),
        body: PageBackground(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RouteMap(route: _route, follow: true),
                  ),
                ),
                const SizedBox(height: 16),
                Text(formatKm(_meters.round()), style: text.displayMedium),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat('Time', formatDuration(_movingMs)),
                    _Stat(
                      kind == ActivityKind.cycle ? 'Speed' : 'Pace',
                      kind == ActivityKind.cycle
                          ? '${(_movingMs <= 0 ? 0 : _meters / 1000 / (_movingMs / 3600000)).toStringAsFixed(1)} km/h'
                          : formatPace(_movingMs, _meters),
                    ),
                    _Stat('kcal', '${(_meters / 1000 * kind.kcalPerKm).round()}'),
                  ],
                ),
                const SizedBox(height: 16),
                if (_problem != null) ...[
                  Text(_problem!, style: text.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  GradientButton(label: tr('Try again'), icon: Icons.refresh_rounded, onPressed: _check),
                ] else
                  ...switch (_phase) {
                    _Phase.checking => [const CircularProgressIndicator()],
                    _Phase.ready => [
                      Text(
                        _accuracy == null
                            ? 'GPS: searching…'
                            : 'GPS: ${RouteTracker.signal(_accuracy!)} (±${_accuracy!.round()} m)',
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      GradientButton(
                        label: tr('Start'),
                        icon: Icons.play_arrow_rounded,
                        onPressed: (_accuracy ?? 99) <= _goodEnough ? _start : null,
                      ),
                    ],
                    _Phase.running || _Phase.paused => [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                              onPressed: _phase == _Phase.running ? _pause : _start,
                              icon: Icon(_phase == _Phase.running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              label: Text(_phase == _Phase.running ? 'Pause' : 'Resume'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GradientButton(label: tr('Finish'), icon: Icons.flag_rounded, onPressed: _confirmFinish),
                          ),
                        ],
                      ),
                    ],
                    _Phase.done => [const SizedBox.shrink()],
                  },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: text.titleLarge),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

/// The summary of a finished run, walk or ride, as a shareable card.
RunReport sessionReport(ActivitySession s) => RunReport(
  id: s.id,
  title: s.title,
  clubName: '',
  kind: s.kind,
  distanceM: s.distanceM,
  timeMs: s.movingMs,
  splitsMs: s.splitsMs,
  route: s.route,
  finishedAt: s.startedAt,
);

/// A list of past runs, walks and rides.
class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(activitiesProvider);
    final text = Theme.of(context).textTheme;
    final total = list.fold(0, (a, s) => a + s.distanceM);
    return Scaffold(
      appBar: AppBar(title: Text(tr('My activities'))),
      body: PageBackground(
        child: list.isEmpty
            ? Center(child: Text(tr('Your runs, walks and rides will show here.'), style: text.bodyLarge))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text('${list.length} activities · ${formatKm(total)} in all', style: text.titleMedium),
                  const SizedBox(height: 10),
                  for (final s in list)
                    Card(
                      elevation: 0,
                      color: AppColors.surface,
                      child: ListTile(
                        leading: Icon(s.kind.icon, color: AppColors.primary),
                        title: Text('${s.title} · ${formatKm(s.distanceM)}'),
                        subtitle: Text(
                          '${DateFormat('d MMM, h:mm a').format(s.startedAt)} · ${formatDuration(s.movingMs)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(Routes.activitySummary, extra: s),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
