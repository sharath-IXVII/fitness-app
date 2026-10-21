import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../workout/routine_providers.dart';
import '../workout/workout_screen.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';

/// Full-screen view while an alarm rings: an animated sunrise over rolling
/// hills. There is no dismiss button — the way out is the workout. Snooze
/// and a deliberately awkward emergency stop exist unless hard mode is on.
class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key, required this.info});

  final RingInfo info;

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  static const _quotes = [
    'Your future self is already thanking you.',
    'Two minutes of effort beats twenty of snoozing.',
    'Champions are made before breakfast.',
    'Move first. Coffee second.',
    'Small reps, every morning, add up to a new you.',
  ];
  late final String _quote = _quotes[DateTime.now().day % _quotes.length];

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

  Future<void> _emergencyStop() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _EmergencyDialog());
    if (ok != true || !mounted) return;
    await AlarmScheduler.silence(widget.info);
    await ref.read(alarmsProvider.notifier).handled(widget.info.alarmId);
    if (mounted) context.go(Routes.home);
  }

  Future<void> _snooze() async {
    HapticFeedback.mediumImpact();
    final info = widget.info;
    await AlarmScheduler.snooze(info);
    if (!mounted) return;
    final until = DateTime.now().add(Duration(minutes: info.snoozeMinutes));
    final messenger = ScaffoldMessenger.of(context);
    context.go(Routes.home);
    messenger.showSnackBar(
      SnackBar(content: Text('Snoozed until ${DateFormat.jm().format(until)} · ${info.snoozesLeft - 1} left')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final info = widget.info;
    final routine = routineById(ref.watch(routinesProvider), info.routineId);
    final canSnooze = !info.hardMode && info.snoozesLeft > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SunriseScene(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(_now).toUpperCase(),
                      style: text.labelMedium?.copyWith(letterSpacing: 1.8, color: AppColors.textSecondary),
                    ).animate().fadeIn(duration: 600.ms),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.jm().format(_now),
                      style: text.displayLarge?.copyWith(fontSize: 72, color: AppColors.textPrimary, height: 1.05),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.15, curve: Curves.easeOutCubic),
                    const SizedBox(height: 10),
                    Text(info.label, style: text.titleLarge).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: 4),
                    Text(
                      _quote,
                      style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ).animate(delay: 500.ms).fadeIn(),
                    const Spacer(),
                    GlassCard(
                      blur: true,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('TO TURN IT OFF', style: text.labelSmall?.copyWith(letterSpacing: 1.3)),
                              const Spacer(),
                              if (info.hardMode)
                                Row(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.danger),
                                    const SizedBox(width: 4),
                                    Text('Hard mode', style: text.labelSmall?.copyWith(color: AppColors.danger)),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (final (i, s) in routine.steps.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(s.exercise.icon, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(s.exercise.label, style: text.titleSmall)),
                                  Text(s.exercise.formatTarget(s.target), style: text.titleSmall),
                                ],
                              ),
                            ).animate(delay: (700 + i * 90).ms).fadeIn().slideX(begin: 0.06),
                        ],
                      ),
                    ).animate(delay: 500.ms).fadeIn(duration: 500.ms).slideY(begin: 0.12),
                    const SizedBox(height: 16),
                    GradientButton(
                          label: 'Start workout',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => context.go(
                            Routes.workout,
                            extra: WorkoutArgs(routineId: routine.id, ring: info),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(end: 1.03, duration: 900.ms, curve: Curves.easeInOut),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (canSnooze)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _snooze,
                              icon: const Icon(Icons.snooze_rounded, size: 18),
                              label: Text('Snooze ${info.snoozeMinutes} min · ${info.snoozesLeft} left'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: AppColors.surface.withValues(alpha: 0.7),
                                side: const BorderSide(color: AppColors.stroke),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                            ),
                          ),
                        if (canSnooze && !info.hardMode) const SizedBox(width: 10),
                        if (!info.hardMode)
                          TextButton(
                            onPressed: _emergencyStop,
                            child: Text('Emergency stop', style: text.bodySmall?.copyWith(color: AppColors.textMuted)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated dawn: the sky warms, the sun rises from behind layered hills,
/// rays turn slowly and a few birds drift across.
class SunriseScene extends StatefulWidget {
  const SunriseScene({super.key});

  @override
  State<SunriseScene> createState() => _SunriseSceneState();
}

class _SunriseSceneState extends State<SunriseScene> with TickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _rise.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: Listenable.merge([_rise, _loop]),
      builder: (_, _) => CustomPaint(
        painter: _SunrisePainter(rise: Curves.easeOutCubic.transform(_rise.value), t: _loop.value),
      ),
    ),
  );
}

class _SunrisePainter extends CustomPainter {
  _SunrisePainter({required this.rise, required this.t});

  final double rise;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Sky: cool cream at the top warming to peach at the horizon as the sun rises.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFFEFE8E0), AppColors.background, rise)!,
            Color.lerp(const Color(0xFFF1DCCB), const Color(0xFFF8DDBF), rise)!,
            Color.lerp(const Color(0xFFE9C3A6), const Color(0xFFF4B88A), rise)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    final horizon = h * 0.62;
    final sunR = w * 0.2;
    final sun = Offset(w / 2, horizon + sunR * 1.4 - rise * sunR * 2.4);
    final pulse = 1 + 0.03 * math.sin(t * math.pi * 2 * 6);

    // Glow and turning rays.
    canvas.drawCircle(
      sun,
      sunR * 3.2 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.sunrise.withValues(alpha: 0.55 * rise),
            AppColors.sunrise.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: sunR * 3.2)),
    );
    final ray = Paint()..color = Colors.white.withValues(alpha: 0.16 * rise);
    for (var i = 0; i < 12; i++) {
      final a = t * math.pi * 2 + i * math.pi / 6;
      final path = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(a - 0.07) * sunR * 4, sun.dy + math.sin(a - 0.07) * sunR * 4)
        ..lineTo(sun.dx + math.cos(a + 0.07) * sunR * 4, sun.dy + math.sin(a + 0.07) * sunR * 4)
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.drawCircle(
      sun,
      sunR,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFFE3B0), Color(0xFFF2A65E)])
            .createShader(Rect.fromCircle(center: sun, radius: sunR)),
    );

    // Birds.
    final bird = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5 * rise)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = ((t * 1.5 + i * 0.27) % 1.2 - 0.1) * w;
      final y = h * (0.3 + i * 0.04) + math.sin(t * 20 + i) * 4;
      final flap = 4 + 2 * math.sin(t * 90 + i * 2);
      canvas.drawPath(
        Path()
          ..moveTo(x - 7, y - flap)
          ..quadraticBezierTo(x - 3, y - 1, x, y)
          ..quadraticBezierTo(x + 3, y - 1, x + 7, y - flap),
        bird,
      );
    }

    // Layered hills in the caramel palette, gently breathing.
    void hill(double base, double amp, double phase, Color color) {
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 6) {
        final y = base + math.sin(x / w * math.pi * 2 + phase + t * math.pi * 2) * amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    hill(horizon + 10, 14, 0.3, const Color(0xFFE7C3A0));
    hill(horizon + 48, 18, 2.1, const Color(0xFFD9A77C));
    hill(horizon + 92, 12, 4.0, const Color(0xFFF3E7D8));
  }

  @override
  bool shouldRepaint(_SunrisePainter old) => old.rise != rise || old.t != t;
}

/// Hold for three seconds, then solve a sum. Annoying on purpose.
class _EmergencyDialog extends StatefulWidget {
  const _EmergencyDialog();

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        setState(() => _unlocked = true);
      }
    });
  final _answer = TextEditingController();
  final _rng = math.Random();
  late final int _a = 12 + _rng.nextInt(30), _b = 3 + _rng.nextInt(7);
  bool _unlocked = false;
  bool _wrong = false;

  @override
  void dispose() {
    _hold.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Emergency stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's workout won't count and your streak may break.", style: text.bodyMedium),
          const SizedBox(height: 20),
          if (!_unlocked)
            GestureDetector(
              onTapDown: (_) => _hold.forward(),
              onTapUp: (_) => _hold.reverse(),
              onTapCancel: () => _hold.reverse(),
              child: AnimatedBuilder(
                animation: _hold,
                builder: (_, _) => Container(
                  height: 54,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppColors.surfaceHigh),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: _hold.value,
                        child: Container(color: AppColors.danger.withValues(alpha: 0.25)),
                      ),
                      Center(child: Text('Press and hold for 3 seconds', style: text.titleSmall)),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Text('What is $_a × $_b?', style: text.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _answer,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Answer', errorText: _wrong ? 'Not quite' : null),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("I'll work out")),
        if (_unlocked)
          TextButton(
            onPressed: () {
              if (int.tryParse(_answer.text.trim()) == _a * _b) {
                Navigator.pop(context, true);
              } else {
                setState(() => _wrong = true);
              }
            },
            child: const Text('Stop alarm', style: TextStyle(color: AppColors.danger)),
          ),
      ],
    );
  }
}
