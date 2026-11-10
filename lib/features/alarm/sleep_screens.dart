import '../../core/i18n/i18n.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/storage.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';
import 'domain/workout_alarm.dart';
import 'sleep_mode.dart';
import 'strict_mode.dart';

/// What the Sleep mode screen needs.
class SleepArgs {
  const SleepArgs({required this.end, required this.block});

  final DateTime end;
  final bool block;
}

// A calm night palette. Sleep screens are dark on purpose: no bright light
// in a bedroom.
const _night = [Color(0xFF0C1226), Color(0xFF060914)];
const _moon = Color(0xFFE9EEFF);
const _dim = Color(0xFF8E9AC0);
const _accent = Color(0xFF8FB0FF);

class _NightScaffold extends StatelessWidget {
  const _NightScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _night.last,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _night),
      ),
      child: SafeArea(child: child),
    ),
  );
}

/// A soft moon with a slow glow and a few twinkling stars.
class _Moon extends StatelessWidget {
  const _Moon({this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: size * 1.5,
                height: size * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_accent.withValues(alpha: 0.28), _accent.withValues(alpha: 0)]),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1.06, 1.06),
                duration: 3.seconds,
                curve: Curves.easeInOut,
              ),
          Icon(Icons.bedtime_rounded, size: size, color: _moon),
          for (final (i, o) in const [Offset(-0.7, -0.6), Offset(0.72, -0.4), Offset(0.55, 0.62)].indexed)
            Positioned(
              left: size * 0.8 + o.dx * size * 0.8,
              top: size * 0.8 + o.dy * size * 0.8,
              child: Icon(Icons.star_rounded, size: 10 + i * 3.0, color: _moon.withValues(alpha: 0.8))
                  .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 700).ms)
                  .fade(begin: 0.2, end: 1, duration: 1800.ms),
            ),
        ],
      ),
    );
  }
}

/// The bedtime alarm's ring screen: a gentle nudge with three choices.
class SleepRing extends ConsumerStatefulWidget {
  const SleepRing({super.key, required this.info});

  final RingInfo info;

  @override
  ConsumerState<SleepRing> createState() => _SleepRingState();
}

class _SleepRingState extends ConsumerState<SleepRing> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  DateTime get _end => clockTimeAfter(DateTime.now(), widget.info.sleepEnd);

  Future<void> _begin() async {
    HapticFeedback.mediumImpact();
    final info = widget.info;
    final router = GoRouter.of(context);
    final prefs = ref.read(sharedPrefsProvider);
    if (info.strict && !await StrictMode.canReopenItself() && mounted) {
      await _askPermission();
    }
    await AlarmScheduler.silence(info);
    await ref.read(alarmsProvider.notifier).handled(info.alarmId);
    final end = _end;
    await SleepMode.start(prefs, end: end, block: info.strict);
    router.go(
      Routes.sleep,
      extra: SleepArgs(end: end, block: info.strict),
    );
  }

  Future<void> _askPermission() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('One more permission')),
        content: Text(
          tr(
            'To keep other apps blocked while you sleep, FittArc needs "Display over other apps". '
            'On the next screen, find FittArc and turn it on.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Skip'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Open settings'))),
        ],
      ),
    );
    if (open == true) await StrictMode.whileAway(StrictMode.openReopenSettings);
  }

  Future<void> _snooze() async {
    HapticFeedback.selectionClick();
    final info = widget.info;
    await AlarmScheduler.snooze(info);
    if (!mounted) return;
    final until = DateTime.now().add(Duration(minutes: info.snoozeMinutes));
    final messenger = ScaffoldMessenger.of(context);
    context.go(Routes.home);
    messenger.showSnackBar(SnackBar(content: Text('Reminder again at ${DateFormat.jm().format(until)}')));
  }

  Future<void> _skip() async {
    await AlarmScheduler.silence(widget.info);
    await ref.read(alarmsProvider.notifier).handled(widget.info.alarmId);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = widget.info;
    final end = DateFormat.jm().format(_end);
    return PopScope(
      canPop: false,
      child: _NightScaffold(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            children: [
              const Spacer(),
              const _Moon(),
              const SizedBox(height: 8),
              Text(
                DateFormat.jm().format(_now),
                style: text.displayLarge?.copyWith(fontSize: 58, color: _moon, height: 1.05),
              ),
              const SizedBox(height: 14),
              Text(tr('Time to sleep'), style: text.headlineSmall?.copyWith(color: _moon)),
              const SizedBox(height: 8),
              Text(
                tr('Put the day away. Tomorrow\'s you will thank you.'),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: _dim),
              ),
              const Spacer(),
              _NightButton(label: tr('Start sleep mode'), icon: Icons.nightlight_round, onTap: _begin),
              const SizedBox(height: 10),
              Text(
                info.strict
                    ? 'Other apps are blocked until $end. Calls still work. If you need to leave it in an emergency, restart your phone.'
                    : 'A calm screen until $end. You can leave it any time.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: _dim),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (info.snoozesLeft > 0)
                    TextButton(
                      onPressed: _snooze,
                      child: Text('Remind me in ${info.snoozeMinutes} min', style: const TextStyle(color: _accent)),
                    ),
                  TextButton(
                    onPressed: _skip,
                    child: Text(tr('Skip tonight'), style: TextStyle(color: _dim)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sleep mode itself: a quiet night screen until the end time. With blocking
/// on, the only things offered are the phone and the emergency number.
class SleepModeScreen extends ConsumerStatefulWidget {
  const SleepModeScreen({super.key, required this.args});

  final SleepArgs args;

  @override
  ConsumerState<SleepModeScreen> createState() => _SleepModeScreenState();
}

class _SleepModeScreenState extends ConsumerState<SleepModeScreen> {
  late final Timer _clock;
  DateTime _now = DateTime.now();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (!_done && !_now.isBefore(widget.args.end)) _finish();
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    _done = true;
    await SleepMode.release(ref.read(sharedPrefsProvider));
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final args = widget.args;
    final end = DateFormat.jm().format(args.end);
    final left = args.end.difference(_now);
    final leftText = left.isNegative ? '' : '${left.inHours} h ${left.inMinutes % 60} min left';
    return PopScope(
      canPop: !args.block,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) SleepMode.release(ref.read(sharedPrefsProvider));
      },
      child: _NightScaffold(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            children: [
              const Spacer(),
              const _Moon(size: 110),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(_now),
                style: text.displayLarge?.copyWith(fontSize: 56, color: _moon, height: 1.05),
              ),
              const SizedBox(height: 10),
              Text(tr('Sleep mode'), style: text.titleLarge?.copyWith(color: _moon)),
              const SizedBox(height: 4),
              Text('Until $end · $leftText', style: text.bodyMedium?.copyWith(color: _dim)),
              const Spacer(),
              if (args.block) ...[
                _NightButton(
                  label: tr('Phone'),
                  icon: Icons.call_rounded,
                  onTap: () => SleepMode.openDialer(),
                  outlined: true,
                ),
                const SizedBox(height: 10),
                _NightButton(
                  label: tr('Emergency 112'),
                  icon: Icons.emergency_rounded,
                  onTap: () => SleepMode.openDialer('112'),
                  outlined: true,
                ),
                const SizedBox(height: 14),
                Text(
                  'Other apps are blocked until $end. Calls still work. '
                  'In an emergency, restarting your phone unlocks everything.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: _dim),
                ),
              ] else ...[
                _NightButton(
                  label: tr('End sleep mode'),
                  icon: Icons.wb_sunny_outlined,
                  onTap: _finish,
                  outlined: true,
                ),
                const SizedBox(height: 14),
                Text(
                  'A calm screen until $end. You can leave it any time.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: _dim),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NightButton extends StatelessWidget {
  const _NightButton({required this.label, required this.icon, required this.onTap, this.outlined = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: outlined ? Colors.transparent : _accent,
        shape: StadiumBorder(side: outlined ? const BorderSide(color: _accent, width: 1.2) : BorderSide.none),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: outlined ? _accent : const Color(0xFF0C1226)),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: outlined ? _accent : const Color(0xFF0C1226),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How long a bedtime lasts, for the alarm list.
String sleepWindowLabel(WorkoutAlarm a) {
  final end = DateTime(2000, 1, 1, a.sleepEnd ~/ 60, a.sleepEnd % 60);
  return 'Sleep mode until ${DateFormat.jm().format(end)}';
}
