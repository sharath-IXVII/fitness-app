import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/festival.dart';
import 'festival_providers.dart';

/// The festival greeting at the top of Today, e.g. "Happy Diwali, Asha".
class FestivalBanner extends ConsumerWidget {
  const FestivalBanner({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(festivalProvider);
    if (f == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final first = name.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [f.colors[0], f.colors[1]],
          ),
          boxShadow: [BoxShadow(color: f.colors[0].withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: FestivalSparkle(festival: f, count: 14)),
            Row(
              children: [
                Text(f.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.isEmpty ? f.greeting : '${f.greeting}, $first!',
                        style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(f.line, style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A light festive sparkle over every page while a festival is on.
class FestivalLayer extends ConsumerWidget {
  const FestivalLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(festivalProvider);
    if (f == null) return const SizedBox.shrink();
    return IgnorePointer(child: FestivalSparkle(festival: f, count: 18, faint: true));
  }
}

/// Softly twinkling dots in the festival's colours. Still when the phone
/// asks for reduced motion.
class FestivalSparkle extends StatefulWidget {
  const FestivalSparkle({super.key, required this.festival, this.count = 18, this.faint = false});

  final Festival festival;
  final int count;
  final bool faint;

  @override
  State<FestivalSparkle> createState() => _FestivalSparkleState();
}

class _FestivalSparkleState extends State<FestivalSparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

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
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _SparklePainter(_c, widget.festival.colors, widget.count, widget.faint),
      size: Size.infinite,
    ),
  );
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t, this.colors, this.count, this.faint) : super(repaint: t);

  final Animation<double> t;
  final List<Color> colors;
  final int count;
  final bool faint;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width, y = rnd.nextDouble() * size.height;
      final phase = rnd.nextDouble();
      final glow = 0.5 + 0.5 * math.sin((t.value + phase) * 2 * math.pi);
      final r = (faint ? 1.6 : 2.2) + 2.2 * glow;
      final c = colors[i % colors.length].withValues(alpha: (faint ? 0.18 : 0.55) + (faint ? 0.22 : 0.4) * glow);
      final p = Paint()..color = c;
      // A four-point star.
      final path = Path()
        ..moveTo(x, y - r * 1.6)
        ..quadraticBezierTo(x, y, x + r * 1.6, y)
        ..quadraticBezierTo(x, y, x, y + r * 1.6)
        ..quadraticBezierTo(x, y, x - r * 1.6, y)
        ..quadraticBezierTo(x, y, x, y - r * 1.6);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.colors != colors || old.count != count;
}
