import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../friends/friends_providers.dart';
import 'clubs_backend.dart';
import 'domain/club.dart';

/// Clubs need an online account, like Friends; null in demo mode.
final clubsBackendProvider = Provider<ClubsBackend?>((ref) {
  final friends = ref.watch(friendsBackendProvider);
  return friends == null ? null : ClubsBackend(friends.db);
});

final discoverClubsProvider = StreamProvider<List<Club>>((ref) {
  final b = ref.watch(clubsBackendProvider);
  if (b == null) return Stream.value(const []);
  return b.discover();
});

final myClubIdsProvider = StreamProvider<Set<String>>((ref) {
  final b = ref.watch(clubsBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return Stream.value(const {});
  return b.myClubIds(uid);
});

final clubProvider = StreamProvider.autoDispose.family<Club?, String>((ref, id) {
  final b = ref.watch(clubsBackendProvider);
  if (b == null) return Stream.value(null);
  return b.watchClub(id);
});

final clubMessagesProvider = StreamProvider.autoDispose.family<List<ClubMessage>, String>((ref, id) {
  final b = ref.watch(clubsBackendProvider);
  if (b == null) return Stream.value(const []);
  return b.messages(id);
});

final clubMembersProvider = StreamProvider.autoDispose.family<Map<String, String>, String>((ref, id) {
  final b = ref.watch(clubsBackendProvider);
  if (b == null) return Stream.value(const {});
  return b.members(id);
});

/// People whose club messages this user chose to hide (after blocking them).
/// Kept on this phone.
class HiddenPeopleNotifier extends Notifier<Set<String>> {
  static const key = 'clubs.hidden.v1';

  @override
  Set<String> build() {
    final raw = ref.read(sharedPrefsProvider).getString(key);
    if (raw == null) return const {};
    try {
      return {for (final v in jsonDecode(raw) as List<dynamic>) v as String};
    } catch (_) {
      return const {};
    }
  }

  Future<void> hide(String uid) async {
    state = {...state, uid};
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode(state.toList()));
  }
}

final hiddenPeopleProvider = NotifierProvider<HiddenPeopleNotifier, Set<String>>(HiddenPeopleNotifier.new);
