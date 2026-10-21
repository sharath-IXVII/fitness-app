import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
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

final targetsProvider = Provider<HealthTargets?>((ref) {
  final profile = ref.watch(profileProvider);
  return profile == null ? null : HealthTargets.from(profile);
});
