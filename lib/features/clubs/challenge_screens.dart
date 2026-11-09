import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../friends/friends_backend.dart' show FriendsFailure;
import '../friends/friends_providers.dart';
import 'clubs_providers.dart';
import 'domain/club.dart';
import 'domain/club_challenge.dart';
import 'gps.dart';

final _day = DateFormat('d MMM, h:mm a');

String _status(ClubChallenge c, DateTime now) {
  if (now.isBefore(c.startsAt)) return 'Starts ${_day.format(c.startsAt)}';
  if (c.openAt(now)) return 'Open until ${_day.format(c.endsAt)}';
  return 'Ended ${_day.format(c.endsAt)}';
}

/// The club's challenges. The admin can set a new one.
class ClubChallengesTab extends ConsumerWidget {
  const ClubChallengesTab({super.key, required this.club, required this.admin});

  final Club club;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final list = ref.watch(clubChallengesProvider(club.id));
    final now = clock.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (admin) ...[
          GradientButton(
            label: 'New challenge',
            icon: Icons.flag_rounded,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _NewChallengeSheet(club: club),
            ),
          ),
          const SizedBox(height: 14),
        ],
        ...list.when(
          loading: () => const [Center(child: CircularProgressIndicator())],
          error: (_, _) => [Text("Couldn't load challenges. Check your internet.", style: text.bodyMedium)],
          data: (cs) => cs.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      admin
                          ? 'Set the first challenge, for example "Run 8 km from the lake gate".'
                          : 'No challenges yet. The club admin sets them.',
                      style: text.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ]
              : [
                  for (final c in cs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Pressable(
                        onTap: () => context.push(Routes.clubChallenge, extra: c),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: c.openAt(now) ? AppColors.primary : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(c.kind.icon, color: c.openAt(now) ? Colors.white : AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.title, style: text.titleMedium),
                                    if (c.title != '${c.kind.label} ${c.distanceLabel}' || c.startName.isNotEmpty)
                                      Text(
                                        [
                                          if (c.title != '${c.kind.label} ${c.distanceLabel}')
                                            '${c.kind.label} ${c.distanceLabel}',
                                          if (c.startName.isNotEmpty) 'from ${c.startName}',
                                        ].join(' · '),
                                        style: text.bodyMedium,
                                      ),
                                    Text(_status(c, now), style: text.bodySmall),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}

class _NewChallengeSheet extends ConsumerStatefulWidget {
  const _NewChallengeSheet({required this.club});

  final Club club;

  @override
  ConsumerState<_NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends ConsumerState<_NewChallengeSheet> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  ActivityKind _kind = ActivityKind.run;
  double _km = 5;

  /// When it starts: null means right away.
  DateTime? _startsAt;

  /// How long it stays open after the start.
  Duration _open = const Duration(days: 1);

  static const _openChoices = [
    (Duration(hours: 1), '1 hour'),
    (Duration(hours: 3), '3 hours'),
    (Duration(days: 1), '1 day'),
    (Duration(days: 7), '7 days'),
    (Duration(days: 30), '30 days'),
  ];

  Future<void> _pickStart() async {
    final now = clock.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Challenge date',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? now.add(const Duration(hours: 1))),
      helpText: 'Start time',
    );
    if (time == null || !mounted) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (at.isBefore(now)) {
        _error = 'Pick a time that is still to come.';
      } else {
        _startsAt = at;
        _error = null;
      }
    });
  }

  (double, double)? _start;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _here() async {
    final gps = ref.read(gpsProvider);
    setState(() => _busy = true);
    final problem = await gps.ensure();
    final fix = problem == null ? await gps.current() : null;
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (fix != null) {
        _start = fix.point;
        _error = null;
      } else {
        _error = problem ?? "Couldn't find your location. Step outside and try again.";
      }
    });
  }

  Future<void> _create() async {
    final me = ref.read(myPublicProfileProvider)!;
    final now = clock.now();
    setState(() => _busy = true);
    try {
      await ref
          .read(clubsBackendProvider)!
          .createChallenge(
            widget.club.id,
            uid: me.uid,
            title: _title.text.trim().isEmpty ? '${_kind.label} ${formatKm(_km * 1000)}' : _title.text,
            kind: _kind,
            distanceM: (_km * 1000).round(),
            startsAt: _startsAt ?? now,
            endsAt: (_startsAt ?? now).add(_open),
            start: _start,
            startName: _start == null ? '' : _place.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on FriendsFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't create it. Check your internet.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New club challenge', style: text.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in ActivityKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 18),
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Distance: ${formatKm(_km * 1000)}', style: text.titleSmall),
            Slider(
              value: _km,
              min: 0.5,
              max: 42,
              divisions: 83,
              label: formatKm(_km * 1000),
              onChanged: (v) => setState(() => _km = v),
            ),
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: 'Name (optional)',
                hintText: '${_kind.label} ${formatKm(_km * 1000)} challenge',
              ),
            ),
            Text('Starts', style: text.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Right now'),
                  selected: _startsAt == null,
                  onSelected: (_) => setState(() => _startsAt = null),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.event_rounded, size: 18),
                  label: Text(_startsAt == null ? 'Pick date & time' : _day.format(_startsAt!)),
                  selected: _startsAt != null,
                  onSelected: (_) => _pickStart(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Open for', style: text.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (d, label) in _openChoices)
                  ChoiceChip(label: Text(label), selected: _open == d, onSelected: (_) => setState(() => _open = d)),
              ],
            ),
            const SizedBox(height: 14),
            if (_start == null)
              OutlinedButton.icon(
                onPressed: _busy ? null : _here,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Start from where I am now (optional)'),
              )
            else ...[
              Row(
                children: [
                  Icon(Icons.place_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Starts here. Members must be within 300 m to begin.', style: text.bodyMedium)),
                  TextButton(onPressed: () => setState(() => _start = null), child: const Text('Clear')),
                ],
              ),
              TextField(
                controller: _place,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Place name', hintText: 'Lake gate'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: 14),
            GradientButton(label: _busy ? 'Please wait…' : 'Create challenge', onPressed: _busy ? null : _create),
          ],
        ),
      ),
    );
  }
}

/// A challenge with its ranking, and Start.
class ClubChallengeScreen extends ConsumerWidget {
  const ClubChallengeScreen({super.key, required this.challenge});

  final ClubChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = challenge;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(myPublicProfileProvider);
    final results = ref.watch(challengeResultsProvider((c.clubId, c.id))).value ?? const <ChallengeResult>[];
    final now = clock.now();
    final admin = ref.watch(clubProvider(c.clubId)).value?.ownerUid == me?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'Delete challenge',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await ref.read(clubsBackendProvider)?.deleteChallenge(c.clubId, c.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(c.kind.icon, color: AppColors.primary, size: 30),
                      const SizedBox(width: 10),
                      Text('${c.kind.label} ${c.distanceLabel}', style: text.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (c.startName.isNotEmpty || c.start != null)
                    Text(
                      'Start: ${c.startName.isEmpty ? 'the set start point' : c.startName} (be within 300 m)',
                      style: text.bodyMedium,
                    ),
                  Text(_status(c, now), style: text.bodyMedium),
                  Text('Finish to earn ${c.finishXp} XP. Fastest time ranks first.', style: text.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _StartButton(challenge: c),
            const SizedBox(height: 22),
            Text('Ranking', style: text.titleLarge),
            const SizedBox(height: 8),
            if (results.isEmpty)
              Text('No one has finished yet. Be the first!', style: text.bodyLarge)
            else
              for (final (i, r) in results.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: r.uid == me?.uid ? AppColors.primarySoft : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.stroke),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(i < 3 ? const ['🥇', '🥈', '🥉'][i] : '${i + 1}', style: text.titleMedium),
                      ),
                      Expanded(child: Text(r.uid == me?.uid ? '${r.name} (you)' : r.name, style: text.titleSmall)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatDuration(r.timeMs), style: text.titleSmall),
                          Text(formatPace(r.timeMs, r.distanceM), style: text.bodySmall),
                        ],
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

/// "Start challenge", enabled only while the challenge is open. Before the
/// start time it counts down and switches on by itself.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.challenge});

  final ClubChallenge challenge;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final now = clock.now();
    final text = Theme.of(context).textTheme;
    final ended = !now.isBefore(c.endsAt);
    final waiting = now.isBefore(c.startsAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientButton(
          label: ended
              ? 'Challenge ended'
              : waiting
              ? 'Starts in ${countdown(c.startsAt.difference(now))}'
              : 'Start challenge',
          icon: ended
              ? Icons.flag_rounded
              : waiting
              ? Icons.lock_clock_rounded
              : Icons.play_arrow_rounded,
          onPressed: c.openAt(now) ? () => context.push(Routes.clubRun, extra: c) : null,
        ),
        const SizedBox(height: 6),
        Text(
          waiting
              ? 'The Start button turns on at ${_day.format(c.startsAt)}.'
              : ended
              ? 'See how everyone did below.'
              : 'Open until ${_day.format(c.endsAt)}.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// "2 d 3 h", "1 h 05 min", "4 min 09 s".
String countdown(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${two(d.inMinutes % 60)} min';
  return '${d.inMinutes} min ${two(d.inSeconds % 60)} s';
}

enum _RunPhase { checking, ready, running, saving, done }

/// Measures the challenge with GPS: start, go, and it finishes by itself at
/// the distance.
class ClubRunScreen extends ConsumerStatefulWidget {
  const ClubRunScreen({super.key, required this.challenge});

  final ClubChallenge challenge;

  @override
  ConsumerState<ClubRunScreen> createState() => _ClubRunScreenState();
}

class _ClubRunScreenState extends ConsumerState<ClubRunScreen> {
  _RunPhase _phase = _RunPhase.checking;
  String? _problem;
  late RouteTracker _tracker = RouteTracker(widget.challenge.kind);
  StreamSubscription<GpsFix>? _sub;
  Timer? _tick;
  DateTime? _startedAt;
  int _elapsed = 0;

  /// Latest GPS accuracy in metres, for the signal check before Start.
  double? _accuracy;

  /// Time from Start to the first reading after it.
  int? _firstFixOffset;

  /// Start needs a signal at least this good.
  static const _goodEnough = 20.0;
  String _result = '';
  int _xp = 0;

  ClubChallenge get c => widget.challenge;

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
      _phase = _RunPhase.checking;
      _problem = null;
    });
    final gps = ref.read(gpsProvider);
    final now = clock.now();
    var problem = now.isBefore(c.startsAt)
        ? 'This challenge starts at ${_day.format(c.startsAt)}.'
        : !c.openAt(now)
        ? 'This challenge has ended.'
        : await gps.ensure();
    if (problem == null && c.start != null) {
      final here = await gps.current();
      if (here == null) {
        problem = "Couldn't find your location. Step outside and try again.";
      } else {
        final away = distanceBetween(here.point, c.start!);
        if (away > ClubChallenge.startRadiusM) {
          problem =
              'Go to the start${c.startName.isEmpty ? '' : ' (${c.startName})'} to begin. '
              'You are ${formatKm(away)} away.';
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _problem = problem;
      _phase = _RunPhase.ready;
    });
    // Warm the GPS up before Start: the first readings are the least accurate.
    if (problem == null) _listen();
  }

  void _listen() {
    _sub ??= ref
        .read(gpsProvider)
        .track()
        .listen(
          _onFix,
          onError: (_) {
            if (mounted) setState(() => _problem = 'Lost the GPS signal. Keep going; it will pick up again.');
          },
        );
  }

  void _onFix(GpsFix f) {
    if (!mounted) return;
    if (_phase != _RunPhase.running) {
      setState(() => _accuracy = f.accuracy);
      return;
    }
    _firstFixOffset ??= clock.now().difference(_startedAt!).inMilliseconds;
    _accuracy = f.accuracy;
    _tracker.add(f, target: c.distanceM);
    setState(() {});
    if (_tracker.meters >= c.distanceM) _finish();
  }

  void _go() {
    HapticFeedback.heavyImpact();
    _tracker = RouteTracker(c.kind);
    _startedAt = clock.now();
    _firstFixOffset = null;
    _elapsed = 0;
    setState(() => _phase = _RunPhase.running);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = clock.now().difference(_startedAt!).inMilliseconds);
    });
    _listen();
  }

  Future<void> _finish() async {
    if (_phase != _RunPhase.running) return;
    // Time from Start to the exact moment the distance was reached, using the
    // GPS readings' own times (worked out between two readings).
    final reached = _tracker.reachedAt(c.distanceM);
    final time = reached != null && _tracker.firstAt != null
        ? (_firstFixOffset ?? 0) + reached.difference(_tracker.firstAt!).inMilliseconds
        : clock.now().difference(_startedAt!).inMilliseconds;
    await _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _RunPhase.saving;
      _elapsed = time;
    });
    final me = ref.read(myPublicProfileProvider)!;
    try {
      final best = await ref
          .read(clubsBackendProvider)!
          .submitResult(c, uid: me.uid, myName: me.name, timeMs: time, distanceM: _tracker.meters.round());
      _xp = await ref.read(clubXpProvider.notifier).award(c.id, c.finishXp);
      _result = best ? 'Saved to the club ranking.' : 'Your earlier time was faster, so it stays on the board.';
    } on FriendsFailure catch (e) {
      _result = e.message;
    } catch (_) {
      _result = "Couldn't save your time. Check your internet.";
    }
    if (mounted) setState(() => _phase = _RunPhase.done);
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Stop the challenge?'),
        content: const Text("It won't count unless you finish the full distance."),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _sub?.cancel();
    _tick?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = (_tracker.meters / c.distanceM).clamp(0.0, 1.0);
    return PopScope(
      canPop: _phase != _RunPhase.running,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _stop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: PageBackground(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 230,
                  height: 230,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        backgroundColor: AppColors.surfaceHigh,
                        color: AppColors.primary,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatKm(_tracker.meters.round()), style: text.displaySmall),
                            Text('of ${c.distanceLabel}', style: text.bodyLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(label: 'Time', value: formatDuration(_elapsed)),
                    _Stat(label: 'Pace', value: formatPace(_elapsed, _tracker.meters)),
                    _Stat(label: 'kcal', value: '${(_tracker.meters / 1000 * c.kind.kcalPerKm).round()}'),
                  ],
                ),
                const Spacer(),
                if (_problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_problem!, style: text.bodyLarge, textAlign: TextAlign.center),
                  ),
                ...switch (_phase) {
                  _RunPhase.checking => [const CircularProgressIndicator()],
                  _RunPhase.ready =>
                    _problem == null
                        ? [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.gps_fixed_rounded,
                                  color: (_accuracy ?? 99) <= _goodEnough ? AppColors.primary : AppColors.amber,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _accuracy == null
                                      ? 'GPS: searching…'
                                      : 'GPS: ${RouteTracker.signal(_accuracy!)} (±${_accuracy!.round()} m)',
                                  style: text.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (_accuracy ?? 99) <= _goodEnough
                                  ? 'Ready. Tap Start and go. It finishes by itself at ${c.distanceLabel}.'
                                  : 'Waiting for a strong GPS signal. Stand in the open, away from tall buildings.',
                              style: text.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            GradientButton(
                              label: 'Start',
                              icon: Icons.play_arrow_rounded,
                              onPressed: (_accuracy ?? 99) <= _goodEnough ? _go : null,
                            ),
                          ]
                        : [GradientButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _check)],
                  _RunPhase.running => [
                    OutlinedButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    ),
                  ],
                  _RunPhase.saving => [const CircularProgressIndicator()],
                  _RunPhase.done => [
                    Text('Finished! 🎉', style: text.headlineMedium),
                    if (_xp > 0) Text('+$_xp XP', style: text.titleLarge?.copyWith(color: AppColors.primary)),
                    Text(_result, style: text.bodyLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    GradientButton(label: 'See ranking', onPressed: () => Navigator.of(context).pop()),
                  ],
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
  const _Stat({required this.label, required this.value});

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
