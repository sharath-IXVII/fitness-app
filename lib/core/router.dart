import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/placeholder/coming_soon_screen.dart';
import '../features/profile/profile_providers.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import 'theme/app_colors.dart';

abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const routine = '/routine';
  static const workout = '/workout';
  static const diet = '/diet';
  static const profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the profile is created or cleared.
  final refresh = ValueNotifier(0);
  ref.listen(profileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == Routes.splash) return null;
      final onboarded = ref.read(profileProvider) != null;
      if (!onboarded && loc != Routes.onboarding) return Routes.onboarding;
      if (onboarded && loc == Routes.onboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, pageBuilder: (_, state) => _fade(state, const OnboardingScreen())),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) => _fade(state, AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.routine,
                builder: (_, _) => const ComingSoonScreen(
                  title: 'My Day',
                  subtitle: 'Build your whole day — alarms, meals, work, workouts — and get reminded at every step.',
                  icon: Icons.view_timeline_rounded,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.workout,
                builder: (_, _) => const ComingSoonScreen(
                  title: 'Workout Alarm',
                  subtitle: 'An alarm that only stops when the camera sees you finish your reps.',
                  icon: Icons.alarm_on_rounded,
                  color: AppColors.workout,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.diet,
                builder: (_, _) => const ComingSoonScreen(
                  title: 'Diet & Food Scan',
                  subtitle: 'Personal meal plans and a camera that reads the protein, carbs and fiber on your plate.',
                  icon: Icons.restaurant_rounded,
                  color: AppColors.diet,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 600),
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);
