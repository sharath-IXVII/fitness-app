import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alarm/alarm_scheduler.dart';
import '../features/arcs/arc_screen.dart';
import '../features/alarm/alarms_screen.dart';
import '../features/alarm/ring_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_screen.dart';
import '../features/challenge/challenge_screen.dart';
import '../features/diet/diet_screen.dart';
import '../features/health/food_guide_screen.dart';
import '../features/health/health_screen.dart';
import '../features/diet/domain/meal_log.dart';
import '../features/friends/friends_screen.dart';
import '../features/home/home_screen.dart';
import '../features/myday/myday_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/privacy_screen.dart';
import '../features/profile/terms_screen.dart';
import '../features/alarm/sleep_screens.dart';
import '../features/profile/profile_providers.dart';
import '../features/progress/achievements_screen.dart';
import '../features/progress/weekly_report_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/steps/steps_screen.dart';
import '../features/training/challenge_plan_screen.dart';
import '../features/training/domain/move.dart';
import '../features/training/domain/plans.dart';
import '../features/training/focus_screen.dart';
import '../features/training/library_screen.dart';
import '../features/training/player_screen.dart';
import '../features/training/training_done_screen.dart';
import '../features/training/training_screen.dart';
import '../features/training/workout_preview_screen.dart';
import '../features/water/water_screen.dart';
import '../features/workout/domain/routine.dart';
import '../features/workout/routine_editor_screen.dart';
import '../features/workout/workout_done_screen.dart';
import '../features/workout/workout_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const training = '/workouts';
  static const trainingFocus = '/workouts/focus';
  static const trainingPreview = '/workouts/preview';
  static const trainingChallenge = '/workouts/challenge';
  static const trainingLibrary = '/workouts/library';
  static const myDay = '/my-day';
  static const alarms = '/alarms';
  static const health = '/health';
  static const diet = '/diet';
  static const foodGuide = '/food-guide';
  static const profile = '/profile';

  // Full-screen flows outside the tab shell.
  static const ring = '/ring';
  static const workout = '/workout';
  static const workoutDone = '/workout-done';
  static const routineEditor = '/routine-editor';
  static const steps = '/steps';
  static const water = '/water';
  static const scan = '/scan';
  static const achievements = '/achievements';
  static const report = '/report';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const sleep = '/sleep';
  static const challenge = '/challenge';
  static const trainingPlayer = '/train';
  static const arc = '/arc';
  static const friends = '/friends';
  static const friendProfile = '/friend';
  static const trainingDone = '/train-done';
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
      // The splash, and the privacy policy and terms (linked from sign-in), are open to all.
      if (loc == Routes.splash || loc == Routes.privacy || loc == Routes.terms) return null;
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
      GoRoute(path: Routes.achievements, builder: (_, _) => const AchievementsScreen()),
      GoRoute(path: Routes.report, builder: (_, _) => const WeeklyReportScreen()),
      GoRoute(path: Routes.privacy, builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: Routes.terms, builder: (_, _) => const TermsScreen()),
      GoRoute(
        path: Routes.sleep,
        redirect: (_, s) => s.extra is SleepArgs ? null : Routes.home,
        pageBuilder: (_, s) => _fade(s, SleepModeScreen(args: s.extra! as SleepArgs)),
      ),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(path: Routes.arc, builder: (_, _) => const ArcScreen()),
      GoRoute(path: Routes.friends, builder: (_, _) => const FriendsScreen()),
      GoRoute(
        path: Routes.friendProfile,
        redirect: (_, s) => s.extra is String ? null : Routes.friends,
        builder: (_, s) => FriendProfileScreen(uid: s.extra! as String),
      ),
      GoRoute(
        path: Routes.trainingPlayer,
        redirect: (_, s) => s.extra is TrainingWorkout ? null : Routes.training,
        pageBuilder: (_, s) => _fade(s, PlayerScreen(workout: s.extra! as TrainingWorkout)),
      ),
      GoRoute(
        path: Routes.trainingDone,
        redirect: (_, s) => s.extra is TrainingDoneArgs ? null : Routes.training,
        pageBuilder: (_, s) => _fade(s, TrainingDoneScreen(args: s.extra! as TrainingDoneArgs)),
      ),
      GoRoute(
        path: Routes.challenge,
        redirect: (_, s) => s.extra is ChallengeArgs ? null : Routes.home,
        pageBuilder: (_, s) => _fade(s, ChallengeScreen(args: s.extra! as ChallengeArgs)),
      ),
      // Health opens from the card on Today, with a back arrow.
      GoRoute(
        path: Routes.health,
        builder: (_, _) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, scrolledUnderElevation: 0),
          body: const HealthScreen(),
        ),
      ),
      GoRoute(path: Routes.foodGuide, builder: (_, _) => const FoodGuideScreen()),
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
            routes: [
              GoRoute(
                path: Routes.training,
                builder: (_, _) => const TrainingScreen(),
                routes: [
                  GoRoute(
                    path: 'focus',
                    redirect: (_, s) => s.extra is BodyFocus ? null : Routes.training,
                    builder: (_, s) => FocusScreen(focus: s.extra! as BodyFocus),
                  ),
                  GoRoute(
                    path: 'preview',
                    redirect: (_, s) => s.extra is TrainingWorkout ? null : Routes.training,
                    builder: (_, s) => WorkoutPreviewScreen(workout: s.extra! as TrainingWorkout),
                  ),
                  GoRoute(
                    path: 'challenge',
                    redirect: (_, s) =>
                        s.extra is String && challengeById(s.extra! as String) != null ? null : Routes.training,
                    builder: (_, s) => ChallengePlanScreen(challenge: challengeById(s.extra! as String)!),
                  ),
                  GoRoute(path: 'library', builder: (_, _) => const LibraryScreen()),
                ],
              ),
            ],
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
          // The fade sits outside TickerMode: pausing a hidden tab's tickers
          // must not freeze its own fade-out, or a half-faded page stays on
          // top after quick tab switches.
          IgnorePointer(
            ignoring: i != index,
            child: AnimatedOpacity(
              opacity: i == index ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: TickerMode(
                enabled: i == index,
                child: ExcludeSemantics(excluding: i != index, child: children[i]),
              ),
            ),
          ),
      ],
    );
  }
}
