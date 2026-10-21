import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
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
    Future.delayed(Duration(milliseconds: AlarmScheduler.ringingNow.isEmpty ? 1400 : 300), () {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 76)
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                .scaleXY(begin: 0.92, end: 1, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 20),
            Text(AppInfo.name, style: text.headlineMedium)
                .animate(delay: 150.ms)
                .fadeIn(duration: 400.ms)
                .moveY(begin: 6, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 6),
            Text(AppInfo.tagline, style: text.bodyMedium).animate(delay: 300.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
