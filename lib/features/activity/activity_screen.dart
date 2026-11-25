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
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/page_background.dart';
import '../clubs/domain/club_challenge.dart';
import '../clubs/domain/run_report.dart';
import '../clubs/gps.dart';
import '../profile/profile_providers.dart';
import '../steps/steps_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'activity_providers.dart';
import 'domain/activity_session.dart';

enum _Phase { checking, ready, running, paused, done }

/// A run, walk or ride on your own: GPS measures distance, time and pace,
/// also with the screen locked; pause any time; Finish saves it.
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

  /// GPS distance only.
  double get _gpsMeters => _parts.fold(0.0, (a, p) => a + p.meters) + (_part?.meters ?? 0);

  /// Steps from the step counter, accelerometer and gyroscope: those in
  /// finished stretches, plus the current one since [_stepsAtStart].
  int _stepsBefore = 0;
  int? _stepsAtStart;
  // Live steps only: Android's background record can jump when it catches up
  // with earlier steps, which must not be added to this walk.
  int get _todaySteps => ref.read(stepsProvider).day.live;
  int get _steps => _stepsBefore + (_stepsAtStart == null ? 0 : (_todaySteps - _stepsAtStart!).clamp(0, 200000));
  bool get _countsSteps => kind != ActivityKind.cycle;

  /// GPS where it worked, steps × stride where it didn't.
  double get _meters => fusedDistance(
    kind: kind,
    gpsMeters: _gpsMeters,
    steps: _steps,
    strideM: ref.read(targetsProvider)?.strideM ?? 0.72,
  );
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
    if (_countsSteps) _stepsAtStart = _todaySteps;
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
    _stepsBefore = _steps;
    _stepsAtStart = null;
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
      steps: _countsSteps ? _steps : 0,
    );
    if (s.distanceM >= 50 || s.steps >= 50) {
      await ref.read(activitiesProvider.notifier).add(s);
      // Ten minutes on the move counts as today's workout.
      if (s.movingMs >= 10 * 60 * 1000) {
        await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(workoutDone: true));
      }
    }
    if (!mounted) return;
    if (s.distanceM < 50 && s.steps < 50) {
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
    // New steps redraw the numbers straight away.
    ref.watch(stepsProvider.select((st) => st.day.live));
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
                _GpsCard(accuracy: _accuracy, phase: _phase, problem: _problem != null),
                const Spacer(),
                Icon(kind.icon, size: 40, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(formatKm(_meters.round()), style: text.displayLarge?.copyWith(fontSize: 64, height: 1.05)),
                Text(tr('Distance'), style: text.titleSmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      _Stat(tr('Time'), formatDuration(_movingMs)),
                      _Stat(
                        kind == ActivityKind.cycle ? tr('Speed') : tr('Pace'),
                        kind == ActivityKind.cycle
                            ? '${(_movingMs <= 0 ? 0 : _meters / 1000 / (_movingMs / 3600000)).toStringAsFixed(1)} km/h'
                            : formatPace(_movingMs, _meters),
                      ),
                      _Stat('kcal', '${(_meters / 1000 * kind.kcalPerKm).round()}'),
                    ],
                  ),
                ),
                if (_countsSteps) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.stroke),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_walk_rounded, color: AppColors.steps),
                        const SizedBox(width: 10),
                        Text(NumberFormat.decimalPattern().format(_steps), style: text.titleLarge),
                        const SizedBox(width: 6),
                        Text(tr('steps'), style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                        const Spacer(),
                        Text(
                          _movingMs < 10000 ? '' : '${(_steps / (_movingMs / 60000)).round()} ${tr('per min')}',
                          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 16),
                if (_problem != null && !(_countsSteps && active)) ...[
                  Text(_problem!, style: text.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  GradientButton(label: tr('Try GPS again'), icon: Icons.refresh_rounded, onPressed: _check),
                  if (_countsSteps) TextButton(onPressed: _start, child: Text(tr('Start without GPS (count steps)'))),
                ] else
                  ...switch (_phase) {
                    _Phase.checking => [const CircularProgressIndicator()],
                    _Phase.ready => [
                      if ((_accuracy ?? 99) > _goodEnough && !_countsSteps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            tr(
                              'Start unlocks when the GPS signal is good. Stand in the open, away from tall buildings.',
                            ),
                            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      GradientButton(
                        label: tr('Start'),
                        icon: Icons.play_arrow_rounded,
                        // Walks and runs also count with the motion sensors, so
                        // they can start without GPS; rides need it.
                        onPressed: _countsSteps || (_accuracy ?? 99) <= _goodEnough ? _start : null,
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
                            child: GradientButton(
                              label: tr('Finish'),
                              icon: Icons.flag_rounded,
                              onPressed: _confirmFinish,
                            ),
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
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleLarge),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// The GPS at a glance: signal bars, how exact it is, and what's happening
/// ("Tracking, also with the screen locked").
class _GpsCard extends StatelessWidget {
  const _GpsCard({required this.accuracy, required this.phase, required this.problem});

  final double? accuracy;
  final _Phase phase;
  final bool problem;

  /// 0 (no fix) to 4 (strong).
  int get _bars {
    final a = accuracy;
    if (a == null || problem) return 0;
    if (a <= 10) return 4;
    if (a <= 20) return 3;
    if (a <= 40) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bars = _bars;
    final color = bars >= 3 ? AppColors.steps : (bars == 2 ? AppColors.amber : AppColors.textMuted);
    final (title, line) = switch (phase) {
      _ when problem && phase == _Phase.running => (
        tr('Counting steps'),
        tr('No GPS: distance comes from your steps.'),
      ),
      _ when problem => (tr('GPS is off'), tr('Turn on location for the most exact distance.')),
      _Phase.checking => (tr('Checking GPS…'), tr('This takes a few seconds.')),
      _Phase.running when (accuracy ?? 99) > 40 => (
        tr('Tracking with steps'),
        tr('GPS is weak here, so steps measure the distance.'),
      ),
      _Phase.running => (tr('Tracking'), tr('GPS and steps together. Keeps going with the screen locked.')),
      _Phase.paused => (tr('Paused'), tr('Distance and time are on hold.')),
      _ when accuracy == null => (tr('Finding GPS…'), tr('Stand in the open for the best signal.')),
      _ => ('${tr('GPS')}: ${tr(RouteTracker.signal(accuracy!))}', '${tr('Accurate to about')} ${accuracy!.round()} m'),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: phase == _Phase.running ? AppColors.steps.withValues(alpha: 0.5) : AppColors.stroke),
      ),
      child: Row(
        children: [
          Icon(
            phase == _Phase.running ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
            color: phase == _Phase.running ? AppColors.steps : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(line, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Signal bars, like the phone's own.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 6,
                  height: 8.0 + i * 5,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: i < bars ? color : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ],
      ),
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
            ? EmptyState(
                icon: Icons.directions_run_rounded,
                title: tr('No activities yet'),
                body: tr('Your runs, walks and rides will show here.'),
                action: tr('Start one'),
                onAction: () => context.go(Routes.training),
              )
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
                          '${DateFormat('d MMM, h:mm a').format(s.startedAt)} · ${formatDuration(s.movingMs)}'
                          '${s.steps > 0 ? ' · ${NumberFormat.decimalPattern().format(s.steps)} steps' : ''}',
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
