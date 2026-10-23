import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/arcs/arc_providers.dart';
import '../../features/arcs/domain/arc.dart';
import '../theme/app_colors.dart';

/// Page canvas shared by every screen, with the current arc's weather
/// drifting behind the content: snow, embers, sunlight or rain.
class PageBackground extends ConsumerWidget {
  const PageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effect = ref.watch(themeSeasonProvider).effect;
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: ArcWeather(effect: effect)),
          child,
        ],
      ),
    );
  }
}

/// Looping particles for [effect]. Still when the system asks for reduced
/// motion.
class ArcWeather extends StatefulWidget {
  const ArcWeather({super.key, required this.effect, this.dark = false, this.count = 22});

  final ArcEffect effect;

  /// Light particles for dark cards.
  final bool dark;
  final int count;

  @override
  State<ArcWeather> createState() => _ArcWeatherState();
}

class _ArcWeatherState extends State<ArcWeather> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _WeatherPainter(widget.effect, _c, dark: widget.dark, count: widget.count),
        size: Size.infinite,
      ),
    ),
  );
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.effect, this.anim, {required this.dark, required this.count}) : super(repaint: anim);

  final ArcEffect effect;
  final Animation<double> anim;
  final bool dark;
  final int count;

  /// Stable pseudo-random value in 0–1 for particle [i], channel [k].
  static double _r(int i, int k) {
    final x = math.sin(i * 127.1 + k * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    switch (effect) {
      case ArcEffect.snow:
        _snow(canvas, size, t);
      case ArcEffect.embers:
        _embers(canvas, size, t);
      case ArcEffect.sun:
        _sun(canvas, size, t);
      case ArcEffect.rain:
        _rain(canvas, size, t);
    }
  }

  Color get _tint => dark ? Colors.white : AppColors.accent;

  void _snow(Canvas canvas, Size size, double t) {
    // A frosty glow along the top edge.
    if (!dark) {
      canvas.drawRect(
        Offset.zero & Size(size.width, 160),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primarySoft, AppColors.primarySoft.withValues(alpha: 0)],
          ).createShader(Offset.zero & Size(size.width, 160)),
      );
    }
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final speed = 0.6 + _r(i, 1) * 0.8;
      final y = ((_r(i, 2) + t * speed * 2) % 1.0) * (size.height + 20) - 10;
      final sway = math.sin((t * 6 + _r(i, 3)) * math.pi * 2) * 10;
      final x = _r(i, 4) * size.width + sway;
      final radius = 1.4 + _r(i, 5) * 2.4;
      paint.color = _tint.withValues(alpha: dark ? 0.3 : 0.35 + _r(i, 6) * 0.2);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _embers(Canvas canvas, Size size, double t) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var i = 0; i < count; i++) {
      final speed = 0.5 + _r(i, 1) * 0.9;
      final p = (_r(i, 2) + t * speed * 2) % 1.0;
      final y = size.height + 10 - p * (size.height + 20);
      final x = _r(i, 4) * size.width + math.sin((t * 5 + _r(i, 3)) * math.pi * 2) * 14;
      final fade = math.sin(p * math.pi);
      paint.color = Color.lerp(AppColors.energy, AppColors.primary, _r(i, 5))!.withValues(alpha: 0.45 * fade);
      canvas.drawCircle(Offset(x, y), 1.2 + _r(i, 6) * 2, paint);
    }
  }

  void _sun(Canvas canvas, Size size, double t) {
    final center = Offset(size.width * 0.95, -20);
    final pulse = 0.9 + 0.1 * math.sin(t * math.pi * 8);
    final r = size.width * 0.75 * pulse;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.energyLight.withValues(alpha: dark ? 0.25 : 0.45),
            AppColors.energyLight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    final paint = Paint();
    for (var i = 0; i < count ~/ 2; i++) {
      final p = (_r(i, 2) + t * (0.3 + _r(i, 1) * 0.4)) % 1.0;
      final x = _r(i, 4) * size.width + math.sin((t * 4 + _r(i, 3)) * math.pi * 2) * 20;
      final y = size.height * (1 - p);
      paint.color = (dark ? Colors.white : AppColors.energy).withValues(alpha: 0.25 * math.sin(p * math.pi));
      canvas.drawCircle(Offset(x, y), 1.5 + _r(i, 5) * 2.5, paint);
    }
  }

  void _rain(Canvas canvas, Size size, double t) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    for (var i = 0; i < count + 8; i++) {
      final speed = 3 + _r(i, 1) * 2;
      final y = ((_r(i, 2) + t * speed * 2) % 1.0) * (size.height + 40) - 20;
      final x = _r(i, 4) * (size.width + 40) - (y / size.height) * 30;
      final len = 10 + _r(i, 5) * 10;
      paint.color = (dark ? Colors.white : AppColors.primary).withValues(alpha: dark ? 0.35 : 0.16);
      canvas.drawLine(Offset(x, y), Offset(x - len * 0.25, y + len), paint);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.effect != effect || old.dark != dark || old.count != count;
}
