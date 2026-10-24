import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../arcs/arc_providers.dart';
import '../arcs/domain/arc.dart';
import 'domain/health_targets.dart';
import 'domain/user_profile.dart';

const _profileKey = 'profile.v1';

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final raw = ref.read(sharedPrefsProvider).getString(_profileKey);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UserProfile profile) async {
    await ref.read(sharedPrefsProvider).setString(_profileKey, jsonEncode(profile.toJson()));
    state = profile;
  }

  Future<void> clear() async {
    await ref.read(sharedPrefsProvider).remove(_profileKey);
    state = null;
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

const _waterGoalKey = 'water.goal.v1';

/// A daily water goal the user typed in (ml), or null to follow the formula.
class WaterGoalNotifier extends Notifier<int?> {
  @override
  int? build() => ref.read(sharedPrefsProvider).getInt(_waterGoalKey);

  Future<void> set(int? ml) async {
    final prefs = ref.read(sharedPrefsProvider);
    ml == null ? await prefs.remove(_waterGoalKey) : await prefs.setInt(_waterGoalKey, ml);
    state = ml;
  }
}

final waterGoalProvider = NotifierProvider<WaterGoalNotifier, int?>(WaterGoalNotifier.new);

/// Daily targets from the profile. Water follows the real season (hotter
/// months need more) unless the user set their own goal.
final targetsProvider = Provider<HealthTargets?>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return null;
  final season = Season.forMonth(ref.watch(todayProvider).month);
  return HealthTargets.from(profile, waterBoostMl: season.waterBoostMl, waterOverrideMl: ref.watch(waterGoalProvider));
});
