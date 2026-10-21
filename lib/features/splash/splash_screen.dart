import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/sunrise_scene.dart';
import '../alarm/alarm_scheduler.dart';
import '../profile/profile_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: AlarmScheduler.ringingNow.isEmpty ? 2900 : 300), () {
      if (!mounted) return;
      final onboarded = ref.read(profileProvider) != null;
      final ringing = AlarmScheduler.ringingNow;
      if (onboarded && ringing.isNotEmpty) {
        context.go(Routes.ring, extra: ringing.first);
      } else {
        context.go(onboarded ? Routes.home : Routes.onboarding);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final barHeight = MediaQuery.sizeOf(context).height * 0.11;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SunriseScene(),
          Align(
            alignment: const Alignment(0, -0.32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 92)
                    .animate()
                    .fadeIn(duration: 900.ms, curve: Curves.easeOut)
                    .blur(begin: const Offset(14, 14), end: Offset.zero, duration: 1100.ms, curve: Curves.easeOutCubic)
                    .scaleXY(begin: 1.18, end: 1, duration: 1400.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),
                // Title "tracks in": wide letter spacing collapsing into place.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Opacity(
                    opacity: (1 - v).clamp(0.0, 1.0),
                    child: Text(AppInfo.name, style: text.displayMedium?.copyWith(letterSpacing: -0.8 + 16 * v)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppInfo.tagline.toUpperCase(),
                  style: text.labelMedium?.copyWith(letterSpacing: 3, color: AppColors.textSecondary),
                ).animate(delay: 1300.ms).fadeIn(duration: 800.ms).slideY(begin: 0.6, curve: Curves.easeOutCubic),
              ],
            ),
          ),
          // Letterbox bars that open like the start of a film.
          for (final top in [true, false])
            Positioned(
              left: 0,
              right: 0,
              top: top ? 0 : null,
              bottom: top ? null : 0,
              height: barHeight,
              child: const ColoredBox(color: AppColors.textPrimary)
                  .animate(delay: 1500.ms)
                  .slideY(begin: 0, end: top ? -1.05 : 1.05, duration: 900.ms, curve: Curves.easeInOutCubic),
            ),
        ],
      ),
    );
  }
}
