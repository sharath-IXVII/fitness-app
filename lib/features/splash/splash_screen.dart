import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/aurora_background.dart';
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
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final onboarded = ref.read(profileProvider) != null;
      context.go(onboarded ? Routes.home : Routes.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: AuroraBackground(
        intensity: 0.12,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(), delay: (i * 700).ms)
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(2.2, 2.2), duration: 1400.ms)
                        .fadeOut(duration: 1400.ms),
                  const AppLogo(size: 96)
                      .animate()
                      .scale(begin: const Offset(0.4, 0.4), duration: 700.ms, curve: Curves.elasticOut)
                      .fadeIn(duration: 300.ms)
                      .then(delay: 200.ms)
                      .shake(hz: 6, rotation: 0.06, duration: 500.ms),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                AppInfo.name,
                style: text.displaySmall,
              ).animate(delay: 400.ms).fadeIn(duration: 600.ms).slideY(begin: 0.4, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(AppInfo.tagline, style: text.bodyMedium)
                  .animate(delay: 700.ms)
                  .fadeIn(duration: 600.ms)
                  .shimmer(delay: 600.ms, duration: 1200.ms, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
