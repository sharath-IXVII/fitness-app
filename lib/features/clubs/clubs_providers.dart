import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:share_plus/share_plus.dart';

import '../../core/storage.dart';
import '../friends/friends_providers.dart';
import 'clubs_backend.dart';
import 'domain/club.dart';
import 'domain/club_challenge.dart';
import 'domain/run_report.dart';

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

final clubChallengesProvider = StreamProvider.autoDispose.family<List<ClubChallenge>, String>((ref, club) {
  final b = ref.watch(clubsBackendProvider);
  if (b == null) return Stream.value(const []);
  return b.challenges(club);
});

final challengeResultsProvider = StreamProvider.autoDispose.family<List<ChallengeResult>, (String, String)>((ref, k) {
  final b = ref.watch(clubsBackendProvider);
  if (b == null) return Stream.value(const []);
  return b.results(k.$1, k.$2);
});

/// XP earned from club challenges, by challenge id (once each). Kept on
/// this phone and added to the level.
class ClubXpNotifier extends Notifier<Map<String, int>> {
  static const key = 'clubs.xp.v1';

  @override
  Map<String, int> build() {
    final raw = ref.read(sharedPrefsProvider).getString(key);
    if (raw == null) return const {};
    try {
      return {for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries) e.key: (e.value as num).toInt()};
    } catch (_) {
      return const {};
    }
  }

  /// Awards [xp] for [challengeId] unless it was already awarded; returns
  /// the XP newly given.
  Future<int> award(String challengeId, int xp) async {
    if (state.containsKey(challengeId)) return 0;
    state = {...state, challengeId: xp};
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode(state));
    return xp;
  }
}

final clubXpProvider = NotifierProvider<ClubXpNotifier, Map<String, int>>(ClubXpNotifier.new);

/// The user's own challenge reports, on this phone only. Each one is
/// removed [RunReport.keepFor] after finishing.
class RunReportsNotifier extends Notifier<List<RunReport>> {
  static const key = 'clubs.reports.v1';

  @override
  List<RunReport> build() {
    final raw = ref.read(sharedPrefsProvider).getString(key);
    if (raw == null) return const [];
    try {
      final now = clock.now();
      final all = [for (final j in jsonDecode(raw) as List<dynamic>) ?RunReport.fromJson(j as Map<String, dynamic>)];
      final live = [
        for (final r in all)
          if (!r.expired(now)) r,
      ];
      if (live.length != all.length) _write(live);
      return live;
    } catch (_) {
      return const [];
    }
  }

  void _write(List<RunReport> list) =>
      ref.read(sharedPrefsProvider).setString(key, jsonEncode([for (final r in list) r.toJson()]));

  Future<void> add(RunReport r) async {
    state = [r, ...state.where((o) => o.id != r.id)];
    _write(state);
  }

  /// Drops reports whose time is up (called when a report screen opens).
  void prune() {
    final now = clock.now();
    if (state.any((r) => r.expired(now))) {
      state = [
        for (final r in state)
          if (!r.expired(now)) r,
      ];
      _write(state);
    }
  }
}

final runReportsProvider = NotifierProvider<RunReportsNotifier, List<RunReport>>(RunReportsNotifier.new);

/// The report for one challenge, if it's still kept.
final runReportProvider = Provider.family<RunReport?, String>((ref, id) {
  final now = clock.now();
  return ref.watch(runReportsProvider).where((r) => r.id == id && !r.expired(now)).firstOrNull;
});

/// Shares plain text through the phone's share sheet. Overridden in tests.
final shareTextProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) async => SharePlus.instance.share(ShareParams(text: text)),
);
