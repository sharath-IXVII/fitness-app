import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arcs/arc_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_service.dart';
import '../profile/profile_providers.dart';
import '../progress/progress_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../training/training_providers.dart';
import 'domain/friends.dart';
import 'friends_backend.dart';

/// Friends needs a real account and the Firebase backend, so it's null in
/// demo mode (before the app is connected to Firebase).
final friendsBackendProvider = Provider<FriendsBackend?>((ref) {
  if (ref.watch(authServiceProvider) is! FirebaseAuthService) return null;
  return FriendsBackend(FirebaseFirestore.instance);
});

/// The signed-in user's id when Friends is available.
final friendsUidProvider = Provider<String?>((ref) {
  if (ref.watch(friendsBackendProvider) == null) return null;
  return ref.watch(authProvider)?.uid;
});

/// What friends see about this user. Updated as XP, streak and badges change.
final myPublicProfileProvider = Provider<PublicProfile?>((ref) {
  final uid = ref.watch(friendsUidProvider);
  final profile = ref.watch(profileProvider);
  if (uid == null || profile == null) return null;
  final badge = ref.watch(bestBadgeProvider);
  final level = ref.watch(levelProvider);
  final streak = ref.watch(streakProvider);
  final arc = ref.watch(currentArcResultProvider);
  return PublicProfile(
    uid: uid,
    name: profile.name.trim().isEmpty ? 'Friend' : profile.name.trim(),
    title: badge?.$1.badgeName(badge.$2),
    titleTier: badge?.$2.index,
    titleSeason: badge?.$1.season.name,
    level: level.number,
    xp: level.xp,
    streak: streak.current,
    bestStreak: streak.longest,
    arcLabel: arc.period.label,
    arcActive: arc.active,
    workoutsWeek: ref.watch(trainingProvider).thisWeek(DateTime.now()).workouts,
  );
});

final challengesProvider = StreamProvider<List<FriendChallenge>>((ref) {
  final b = ref.watch(friendsBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return Stream.value(const []);
  return b.challenges(uid);
});

final friendsListProvider = StreamProvider<List<PublicProfile>>((ref) {
  final b = ref.watch(friendsBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return Stream.value(const []);
  return b.friends(uid);
});

/// Friend requests waiting for this user.
final friendRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final b = ref.watch(friendsBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return Stream.value(const []);
  return b.incomingRequests(uid);
});

/// This user's friend code (made on first use).
final myFriendCodeProvider = FutureProvider<String?>((ref) async {
  final b = ref.watch(friendsBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return null;
  return b.myFriendCode(uid);
});

/// Challenges waiting on this user: to do, or to answer.
final challengesToDoProvider = Provider<int>((ref) {
  final uid = ref.watch(friendsUidProvider);
  if (uid == null) return 0;
  final list = ref.watch(challengesProvider).value ?? const [];
  final requests = ref.watch(friendRequestsProvider).value?.length ?? 0;
  return requests + list.where((c) => c.status == ChallengeStatus.accepted && !c.doneBy(uid)).length;
});

/// One person's public profile, live. Cached per id.
final friendProfileProvider = StreamProvider.autoDispose.family<PublicProfile?, String>((ref, uid) {
  final b = ref.watch(friendsBackendProvider);
  if (b == null) return Stream.value(null);
  return b.watchProfile(uid);
});
