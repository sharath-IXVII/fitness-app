import 'dart:math' as math;

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

/// Opening sequence, continuing from the Android launch screen (which shows
/// the plain logo tile in the same spot):
///   1. the white clock and check draw themselves onto the tile,
///   2. the tile settles with a soft pulse and lifts slightly,
///   3. the app name rises in letter by letter, then the tagline,
///   4. the logo flies (Hero) into its place on the next screen.
class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2300);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final draw = _seg(0.0, 0.45, Curves.linear);
          // A gentle settle after the mark completes: 1 → 1.06 → 1.
          final pulse = 1 + 0.06 * math.sin(math.pi * _seg(0.42, 0.6, Curves.easeInOut));
          final lift = _seg(0.5, 0.72);
          // Full-screen so the logo sits exactly where the launch screen drew it.
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(0, -44 * lift),
                  child: Transform.scale(
                    scale: pulse,
                    child: AppLogo(size: 76, progress: draw),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Letters(
                          text: AppInfo.name.toUpperCase(),
                          progress: _seg(0.55, 0.85),
                          style: text.displaySmall?.copyWith(letterSpacing: 4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: _seg(0.75, 0.92),
                        child: Text(AppInfo.tagline, style: text.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: SafeArea(
                  top: false,
                  child: Opacity(
                    opacity: _seg(0.8, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SPONSORED BY',
                          style: text.labelSmall?.copyWith(color: AppColors.textTertiary, letterSpacing: 2.4),
                        ),
                        const SizedBox(height: 2),
                        Text(AppInfo.sponsor, style: text.titleMedium?.copyWith(color: AppColors.primary)),
                      ],
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
