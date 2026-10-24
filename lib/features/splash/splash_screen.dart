import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../alarm/alarm_scheduler.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// Opening sequence. It continues straight from the Android launch screen
/// (the lime logo on black), so nothing jumps:
///   1. the lime logo holds where the launch screen drew it,
///   2. it turns into the logo of the current season, which assembles with
///      that season's weather,
///   3. the app name rises in letter by letter, then the tagline,
///   4. "Sponsored by GetYr_io" fades in and stays for a moment,
///   5. the logo flies (Hero) to its place on the next screen.
class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 5200);
  late final _c = AnimationController(vsync: this, duration: _total);

  @override
  void initState() {
    super.initState();
    final ringing = AlarmScheduler.ringingNow.isNotEmpty;
    if (ringing) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    Future.delayed(ringing ? const Duration(milliseconds: 200) : _total, _next);
  }

  void _next() {
    if (!mounted) return;
    final signedIn = ref.read(authProvider) != null;
    final onboarded = ref.read(profileProvider) != null;
    final ringing = AlarmScheduler.ringingNow;
    if (onboarded && ringing.isNotEmpty) {
      context.go(Routes.ring, extra: ringing.first);
    } else {
      context.go(!signedIn ? Routes.auth : (onboarded ? Routes.home : Routes.onboarding));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const bg = Color(0xFF111111);
    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // 0–0.14 the lime logo holds; 0.14–0.2 it hands over to the season's logo.
          final handOver = _seg(0.14, 0.22, Curves.easeInOut);
          final draw = _seg(0.16, 0.5, Curves.linear);
          final lift = _seg(0.5, 0.68);
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(0, -56 * lift),
                  child: SizedBox.square(
                    dimension: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 1 - handOver,
                          child: Transform.scale(
                            scale: 1 - 0.15 * handOver,
                            child: const SizedBox.square(dimension: 132, child: CustomPaint(painter: _LimeMark())),
                          ),
                        ),
                        if (handOver > 0) AppLogo(size: 132, progress: draw, alive: true),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 62),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Letters(
                          text: AppInfo.name.toUpperCase(),
                          progress: _seg(0.5, 0.74),
                          style: text.displaySmall?.copyWith(letterSpacing: 4, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _seg(0.66, 0.8),
                        child: Text(AppInfo.tagline, style: text.bodyMedium?.copyWith(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
                child: SafeArea(
                  top: false,
                  child: Opacity(
                    opacity: _seg(0.74, 0.86),
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - _seg(0.74, 0.86))),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SPONSORED BY',
                            style: text.labelSmall?.copyWith(color: Colors.white54, letterSpacing: 2.8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppInfo.sponsor,
                            style: text.titleLarge?.copyWith(color: AppColors.energyLight, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The lime logo exactly as the Android launch screen draws it (traced from
/// the master artwork, same 346×411 shape).
class _LimeMark extends CustomPainter {
  const _LimeMark();

  static const _blocks = <List<Offset>>[
    [Offset(595, 316), Offset(863, 316), Offset(941, 397), Offset(675, 397), Offset(675, 518), Offset(595, 433)],
    [
      Offset(703, 467),
      Offset(839, 467),
      Offset(839, 545),
      Offset(759, 545),
      Offset(759, 727),
      Offset(668, 635),
      Offset(668, 527),
      Offset(703, 562),
    ],
    [Offset(817, 414), Offset(885, 414), Offset(932, 467), Offset(932, 560), Offset(851, 627), Offset(851, 467)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Same placement as splash_icon.xml: the mark is 0.3 of a 240 box.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 240 * 0.3);
    canvas.translate(-768, -521.5);
    final paint = Paint()..color = const Color(0xFFB4FF0A);
    for (final b in _blocks) {
      canvas.drawPath(Path()..addPolygon(b, true), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LimeMark old) => false;
}

/// Reveals [text] one letter at a time, each fading in as it rises.
class _Letters extends StatelessWidget {
  const _Letters({required this.text, required this.progress, this.style});

  final String text;
  final double progress;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final n = text.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          Builder(
            builder: (_) {
              // Each letter animates over 40% of the span, staggered evenly.
              final start = i / n * 0.6;
              final t = Curves.easeOutCubic.transform(((progress - start) / 0.4).clamp(0.0, 1.0));
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t)),
                  child: Text(text[i], style: style),
                ),
              );
            },
          ),
      ],
    );
  }
}
