import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import 'domain/routine.dart';

class WorkoutDoneArgs {
  const WorkoutDoneArgs({
    required this.routine,
    required this.results,
    required this.duration,
    required this.fromAlarm,
  });

  final Routine routine;
  final List<int> results;
  final Duration duration;
  final bool fromAlarm;
}

class WorkoutDoneScreen extends StatelessWidget {
  const WorkoutDoneScreen({super.key, required this.args});

  final WorkoutDoneArgs args;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mins = args.duration.inMinutes, secs = args.duration.inSeconds % 60;
    final totalReps = [
      for (var i = 0; i < args.results.length; i++)
        if (!args.routine.steps[i].exercise.timed) args.results[i],
    ].fold(0, (a, b) => a + b);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AuroraBackground(
          colors: const [AppColors.accent, AppColors.gold, AppColors.sunrise],
          intensity: 0.14,
          child: Stack(
            children: [
              const Positioned.fill(child: IgnorePointer(child: _Confetti())),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.brandGradient,
                          boxShadow: AppColors.softShadow(AppColors.primary),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut, begin: const Offset(0.3, 0.3)),
                      const SizedBox(height: 24),
                      Text(
                        args.fromAlarm ? 'Alarm off. You earned it.' : 'Workout complete!',
                        style: text.headlineMedium,
                        textAlign: TextAlign.center,
                      ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                      const SizedBox(height: 8),
                      Text("Today's workout square is lit up.", style: text.bodyMedium).animate(delay: 300.ms).fadeIn(),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          _stat(context, 'Total reps', totalReps, ''),
                          const SizedBox(width: 12),
                          _stat(context, 'Time', mins, 'm ${secs}s'),
                          const SizedBox(width: 12),
                          _stat(context, 'Exercises', args.results.length, ''),
                        ],
                      ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (var i = 0; i < args.results.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    Icon(args.routine.steps[i].exercise.icon, size: 20, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(args.routine.steps[i].exercise.label, style: text.titleSmall)),
                                    Text(
                                      args.routine.steps[i].exercise.formatTarget(args.results[i]),
                                      style: text.titleSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ).animate(delay: 500.ms).fadeIn(),
                      const Spacer(),
                      GradientButton(label: 'Back to Today', onPressed: () => context.go(Routes.home)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, String suffix) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            AnimatedNumber(
              value,
              suffix: suffix,
              style: text.titleLarge?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// A one-shot burst of falling confetti.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  final _pieces = List.generate(70, (i) => _Piece(math.Random(i)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value, _pieces)),
  );
}

class _Piece {
  _Piece(math.Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.3,
      speed = 0.7 + r.nextDouble() * 0.6,
      drift = (r.nextDouble() - 0.5) * 0.3,
      spin = r.nextDouble() * 12,
      size = 6 + r.nextDouble() * 6,
      color = const [
        AppColors.primary,
        AppColors.accent,
        AppColors.gold,
        AppColors.water,
        AppColors.protein,
      ][r.nextInt(5)];

  final double x, delay, speed, drift, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.pieces);

  final double t;
  final List<_Piece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = (p.x + p.drift * local + 0.02 * math.sin(local * 10 + p.spin)) * size.width;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - local * 0.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
