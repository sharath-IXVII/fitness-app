import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alarm/alarm_scheduler.dart';
import '../features/alarm/alarms_screen.dart';
import '../features/alarm/ring_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/phone_screen.dart';
import '../features/diet/diet_screen.dart';
import '../features/diet/domain/meal_log.dart';
import '../features/home/home_screen.dart';
import '../features/myday/myday_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_providers.dart';
import '../features/profile/profile_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/steps/steps_screen.dart';
import '../features/water/water_screen.dart';
import '../features/workout/domain/routine.dart';
import '../features/workout/routine_editor_screen.dart';
import '../features/workout/workout_done_screen.dart';
import '../features/workout/workout_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const auth = '/auth';
  static const authPhone = '/auth/phone';
  static const authOtp = '/auth/otp';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const myDay = '/my-day';
  static const alarms = '/alarms';
  static const diet = '/diet';
  static const profile = '/profile';

  // Full-screen flows outside the tab shell.
  static const ring = '/ring';
  static const workout = '/workout';
  static const workoutDone = '/workout-done';
  static const routineEditor = '/routine-editor';
  static const steps = '/steps';
  static const water = '/water';
  static const scan = '/scan';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the user signs in/out or the profile changes.
  final refresh = ValueNotifier(0);
  ref.listen(profileProvider, (_, _) => refresh.value++);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == Routes.splash) return null;
      // Signed out → auth flow. Signed in → onboarding until a profile exists.
      final inAuth = loc.startsWith(Routes.auth);
      if (ref.read(authProvider) == null) return inAuth ? null : Routes.auth;
      final onboarded = ref.read(profileProvider) != null;
      if (!onboarded) return loc == Routes.onboarding ? null : Routes.onboarding;
      if (inAuth || loc == Routes.onboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.auth,
        // Slower fade so the logo has time to fly in from the splash.
        pageBuilder: (_, s) => _fade(s, const AuthScreen(), duration: const Duration(milliseconds: 650)),
        routes: [
          GoRoute(
            path: 'phone',
            pageBuilder: (_, s) => _sharedAxis(s, PhoneScreen(signUp: s.extra as bool? ?? true)),
          ),
          GoRoute(
            path: 'otp',
            redirect: (_, s) => s.extra is OtpArgs ? null : Routes.authPhone,
            pageBuilder: (_, s) => _sharedAxis(s, OtpScreen(args: s.extra! as OtpArgs)),
          ),
        ],
      ),
      GoRoute(path: Routes.onboarding, pageBuilder: (_, state) => _fade(state, const OnboardingScreen())),
      GoRoute(
        path: Routes.ring,
        redirect: (_, s) => s.extra is RingInfo ? null : Routes.home,
        pageBuilder: (_, s) => _fade(s, RingScreen(info: s.extra! as RingInfo)),
      ),
      GoRoute(
        path: Routes.workout,
        redirect: (_, s) => s.extra is WorkoutArgs ? null : Routes.home,
        pageBuilder: (_, s) => _fade(s, WorkoutScreen(args: s.extra! as WorkoutArgs)),
      ),
      GoRoute(
        path: Routes.workoutDone,
        redirect: (_, s) => s.extra is WorkoutDoneArgs ? null : Routes.home,
        pageBuilder: (_, s) => _fade(s, WorkoutDoneScreen(args: s.extra! as WorkoutDoneArgs)),
      ),
      GoRoute(path: Routes.steps, builder: (_, _) => const StepsScreen()),
      GoRoute(path: Routes.water, builder: (_, _) => const WaterScreen()),
      GoRoute(
        path: Routes.scan,
        builder: (_, s) => ScanFoodScreen(meal: s.extra is MealType ? s.extra! as MealType : MealType.lunch),
      ),
      GoRoute(
        path: Routes.routineEditor,
        builder: (_, s) => RoutineEditorScreen(routine: s.extra is Routine ? s.extra! as Routine : null),
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: (_, shell, children) =>
            _FadingBranches(index: shell.currentIndex, children: children),
        pageBuilder: (_, state, shell) => _fade(state, AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.myDay, builder: (_, _) => const MyDayScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.alarms, builder: (_, _) => const AlarmsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.diet, builder: (_, _) => const DietScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});

/// Quiet route transition: a short fade with an 8 px rise.
CustomTransitionPage<void> _fade(
  GoRouterState state,
  Widget child, {
  Duration duration = const Duration(milliseconds: 280),
}) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: duration,
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);

/// Material "shared axis" (horizontal) for step-by-step flows: the new step
/// slides in from the right while fading; the old one drifts left and fades.
CustomTransitionPage<void> _sharedAxis(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 320),
  transitionsBuilder: (_, animation, secondary, child) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondary, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(inCurve),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0.2, 1)),
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.08, 0)).animate(outCurve),
          child: FadeTransition(opacity: Tween(begin: 1.0, end: 0.0).animate(outCurve), child: child),
        ),
      ),
    );
  },
);

/// Keeps every tab alive (like an IndexedStack) with a short cross-fade.
class _FadingBranches extends StatelessWidget {
  const _FadingBranches({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: TickerMode(
              enabled: i == index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: ExcludeSemantics(excluding: i != index, child: children[i]),
              ),
            ),
          ),
      ],
    );
  }
}
