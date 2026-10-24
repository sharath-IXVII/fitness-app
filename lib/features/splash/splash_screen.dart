import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../alarm/alarm_scheduler.dart';
import '../arcs/arc_providers.dart';
import '../auth/auth_providers.dart';
import '../profile/profile_providers.dart';
import 'season_weather.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// Opening sequence, on a light background that continues from the Android
/// launch screen:
///   1. the season's weather arrives across the whole screen (snowfall in
///      Winter, petals, golden light or rain),
///   2. the logo assembles in the season's colours,
///   3. "FITTIEPI" and "The Rise of Arcs" appear,
///   4. "Sponsored by GetYr_io" fades in at the bottom and stays a moment.
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
    final season = ref.watch(themeSeasonProvider);
    final look = SeasonLook.of(season);
    const ink = Color(0xFF14233F);
    const slate = Color(0xFF5C6B86);
    return Scaffold(
      backgroundColor: SeasonLook.launch,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final seconds = _c.value * _total.inMilliseconds / 1000;
          // The launch colour melts into the season's own light gradient.
          final tint = _seg(0.0, 0.14, Curves.easeOut);
          final weather = _seg(0.02, 0.3, Curves.easeOut);
          final mark = _seg(0.28, 0.58, Curves.linear);
          final shine = _seg(0.56, 0.74, Curves.easeInOut);
          final rise = _seg(0.5, 0.66);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: tint,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [look.top, look.bottom],
                    ),
                  ),
                ),
              ),
              CustomPaint(
                painter: SeasonWeatherPainter(season: season, seconds: seconds, intensity: weather),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, -34 * rise),
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: CustomPaint(
                      painter: BrandMarkPainter(look: look, progress: mark, shine: shine),
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 84),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Letters(
                          text: AppInfo.name.toUpperCase(),
                          progress: _seg(0.56, 0.78),
                          style: text.displaySmall?.copyWith(letterSpacing: 5, color: ink),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: _seg(0.7, 0.84),
                        child: Text(
                          AppInfo.tagline,
                          style: text.titleSmall?.copyWith(
                            color: slate,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: SafeArea(
                  top: false,
                  child: Opacity(
                    opacity: _seg(0.76, 0.9),
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _seg(0.76, 0.9))),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 120 * _seg(0.78, 0.92),
                            height: 1.2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  look.markLight.withValues(alpha: 0),
                                  look.markDeep,
                                  look.markLight.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'SPONSORED BY',
                            style: text.labelSmall?.copyWith(color: const Color(0xFF7C8AA3), letterSpacing: 3.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppInfo.sponsor,
                            style: text.titleLarge?.copyWith(
                              color: ink,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
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
