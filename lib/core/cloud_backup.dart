import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../features/activity/activity_providers.dart';
import '../features/activity/domain/activity_session.dart';
import '../features/clubs/clubs_providers.dart';
import '../features/health/widgets/body_check_sheet.dart' show bodyCheckKey;
import '../features/arcs/arc_providers.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_service.dart';
import '../features/profile/profile_providers.dart';
import '../features/progress/domain/progress.dart';
import '../features/progress/progress_providers.dart';
import '../features/streaks/daily_log_providers.dart';
import 'storage.dart';

/// What is kept in the cloud for one account: every day's log, plus the
/// profile, the badges ever earned, the start date and the water goal.
class BackupSnapshot {
  const BackupSnapshot({this.days = const {}, this.state});

  /// "yyyy-MM-dd" → the day's log JSON.
  final Map<String, Map<String, dynamic>> days;

  /// {profile, badges, firstUse, waterGoal}, or null if nothing is stored.
  final Map<String, dynamic>? state;
}

/// Where backups live. A seam so tests can use a fake.
abstract class CloudStore {
  Future<BackupSnapshot> load(String uid);
  Future<void> saveDays(String uid, Map<String, Map<String, dynamic>> days);
  Future<void> saveState(String uid, Map<String, dynamic> state);
  Future<void> delete(String uid);
}

/// Cloud Firestore layout (see firestore.rules):
///   users/{uid}/days/{yyyy-MM-dd}   one document per day
///   users/{uid}/backup/state        profile, badges, start date, water goal
class FirestoreCloudStore implements CloudStore {
  FirestoreCloudStore(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _me(String uid) => _db.collection('users').doc(uid);

  @override
  Future<BackupSnapshot> load(String uid) async {
    final days = await _me(uid).collection('days').get();
    final state = await _me(uid).collection('backup').doc('state').get();
    return BackupSnapshot(days: {for (final d in days.docs) d.id: d.data()}, state: state.data());
  }

  @override
  Future<void> saveDays(String uid, Map<String, Map<String, dynamic>> days) async {
    // Batches hold at most 500 writes.
    final entries = days.entries.toList();
    for (var i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(400)) {
        batch.set(_me(uid).collection('days').doc(e.key), e.value);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> saveState(String uid, Map<String, dynamic> state) =>
      _me(uid).collection('backup').doc('state').set({...state, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> delete(String uid) async {
    for (final d in (await _me(uid).collection('days').get()).docs) {
      await d.reference.delete();
    }
    for (final d in (await _me(uid).collection('backup').get()).docs) {
      await d.reference.delete();
    }
  }
}

/// Null in demo mode (no Firebase), so backup is simply off there.
final cloudStoreProvider = Provider<CloudStore?>((ref) {
  if (ref.watch(authServiceProvider) is! FirebaseAuthService) return null;
  return FirestoreCloudStore(FirebaseFirestore.instance);
});

/// The rules for combining a phone's data with the cloud's. They only ever
/// keep the better of the two, so a fresh install can't wipe progress and an
/// old phone can't roll it back.
abstract final class BackupMerge {
  /// One day: done stays done, and counts take the higher figure.
  static Map<String, dynamic> day(Map<String, dynamic> a, Map<String, dynamic> b) {
    int n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    return {
      'workout': (a['workout'] == true) || (b['workout'] == true),
      for (final k in const ['water', 'steps', 'meals', 'protein']) k: n(a, k) > n(b, k) ? n(a, k) : n(b, k),
    };
  }

  /// Badges: everything from both sides, with the earlier date for each.
  static Map<String, String> badges(Map<String, dynamic> a, Map<String, dynamic> b) {
    final out = <String, String>{};
    for (final m in [a, b]) {
      for (final e in m.entries) {
        final v = '${e.value}';
        final old = out[e.key];
        if (old == null || v.compareTo(old) < 0) out[e.key] = v;
      }
    }
    return out;
  }

  /// The earlier of two dates written as yyyy-MM-dd (either may be absent).
  static String? earlier(String? a, String? b) => a == null ? b : (b == null ? a : (a.compareTo(b) <= 0 ? a : b));
}

/// Backs up progress to the cloud and brings it back on a new phone.
class CloudBackup {
  CloudBackup(this._ref);

  final Ref _ref;
  static final _dateKey = DateFormat('yyyy-MM-dd');
  static const _sentKey = 'cloud.sent.v1';
  static const _firstUseKey = 'app.firstUse.v1';
  Timer? _timer;
  bool _busy = false;

  String? get _uid => _ref.read(authProvider)?.uid;
  CloudStore? get _store => _ref.read(cloudStoreProvider);

  /// Pulls the account's data and merges it into this phone. Returns true if
  /// anything was found. Never throws: a failed restore must not block sign-in.
  Future<bool> restore(String uid) async {
    final store = _store;
    if (store == null) return false;
    try {
      final snap = await store.load(uid).timeout(const Duration(seconds: 12));
      if (snap.days.isEmpty && snap.state == null) return false;
      final prefs = _ref.read(sharedPrefsProvider);

      for (final e in snap.days.entries) {
        if (_dateKey.tryParse(e.key) == null) continue;
        final key = 'log.v1.${e.key}';
        final local = prefs.getString(key);
        final merged = local == null
            ? BackupMerge.day(e.value, const {})
            : BackupMerge.day(e.value, jsonDecode(local) as Map<String, dynamic>);
        await prefs.setString(key, jsonEncode(merged));
      }

      final state = snap.state;
      if (state != null) {
        final profile = state['profile'];
        if (prefs.getString('profile.v1') == null && profile is Map) {
          await prefs.setString('profile.v1', jsonEncode(profile));
        }
        final badges = state['badges'];
        if (badges is Map) {
          final parsed = <BadgeKey, DateTime>{};
          for (final e in badges.entries) {
            final k = parseBadgeId('${e.key}'), d = DateTime.tryParse('${e.value}');
            if (k != null && d != null) parsed[k] = d;
          }
          _ref.invalidate(badgeVaultProvider);
          await _ref.read(badgeVaultProvider.notifier).merge(parsed);
        }
        final first = state['firstUse'] as String?;
        final localFirst = prefs.getString(_firstUseKey);
        final best = BackupMerge.earlier(first, localFirst?.substring(0, 10));
        if (best != null) await prefs.setString(_firstUseKey, DateTime.parse(best).toIso8601String());
        final goal = state['waterGoal'];
        if (goal is int && prefs.getInt('water.goal.v1') == null) await prefs.setInt('water.goal.v1', goal);
        // Bonus XP: keep everything from both sides.
        final xp = state['xpBonus'];
        if (xp is Map) {
          for (final e in xp.entries) {
            if (e.value is num) await _ref.read(clubXpProvider.notifier).award('${e.key}', (e.value as num).toInt());
          }
        }
        // Activities: add the ones this phone doesn't have.
        final acts = state['activities'];
        if (acts is List) {
          final have = {for (final a in _ref.read(activitiesProvider)) a.id};
          for (final j in acts.whereType<Map<String, dynamic>>()) {
            final a = ActivitySession.fromJson(j);
            if (a != null && !have.contains(a.id)) await _ref.read(activitiesProvider.notifier).add(a);
          }
        }
        final body = state['body'];
        if (body is Map && prefs.getString(bodyCheckKey) == null) {
          await prefs.setString(bodyCheckKey, jsonEncode(body));
        }
      }
      // Phone data and cloud data now agree on what's stored; let the app
      // re-read it. Everything restored counts as already backed up.
      await prefs.remove(_sentKey);
      _ref.invalidate(profileProvider);
      _ref.invalidate(dailyLogsProvider);
      _ref.invalidate(firstUseProvider);
      _ref.invalidate(waterGoalProvider);
      return true;
    } catch (e) {
      debugPrint('cloud restore failed: $e');
      return false;
    }
  }

  /// Backs up soon (changes arrive in bursts, so wait a little).
  void schedule({Duration after = const Duration(seconds: 20)}) {
    if (_store == null || _uid == null) return;
    _timer?.cancel();
    _timer = Timer(after, () => push());
  }

  /// Uploads whatever changed since the last upload.
  Future<void> push() async {
    final store = _store, uid = _uid;
    if (store == null || uid == null || _busy) return;
    _busy = true;
    try {
      final prefs = _ref.read(sharedPrefsProvider);
      final sentRaw = prefs.getString(_sentKey);
      final sent = sentRaw == null ? <String, dynamic>{} : jsonDecode(sentRaw) as Map<String, dynamic>;

      final days = <String, Map<String, dynamic>>{};
      for (final e in _ref.read(dailyLogsProvider).entries) {
        final json = e.value.toJson();
        final id = _dateKey.format(e.key);
        if (sent[id] != jsonEncode(json)) days[id] = json;
      }
      final profile = _ref.read(profileProvider);
      final first = _ref.read(firstUseProvider);
      final goal = _ref.read(waterGoalProvider);
      final state = <String, dynamic>{
        if (profile != null) 'profile': profile.toJson(),
        'badges': {for (final e in _ref.read(badgeVaultProvider).entries) badgeId(e.key): _dateKey.format(e.value)},
        'firstUse': _dateKey.format(first),
        'waterGoal': ?goal,
        // Bonus XP (club challenges, invites), activity history without the
        // map route (kept small), and body-check measurements.
        'xpBonus': _ref.read(clubXpProvider),
        'activities': [
          for (final a in _ref.read(activitiesProvider).take(ActivitiesNotifier.keep)) {...a.toJson()}..remove('r'),
        ],
        'body': ?_bodyCheck(prefs),
      };
      final stateJson = jsonEncode(state);

      if (days.isNotEmpty) await store.saveDays(uid, days);
      if (sent['_state'] != stateJson) await store.saveState(uid, state);
      await prefs.setString(
        _sentKey,
        jsonEncode({...sent, for (final e in days.entries) e.key: jsonEncode(e.value), '_state': stateJson}),
      );
    } catch (e) {
      debugPrint('cloud backup failed: $e');
    } finally {
      _busy = false;
    }
  }

  void dispose() => _timer?.cancel();

  static Map<String, dynamic>? _bodyCheck(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(bodyCheckKey);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

final cloudBackupProvider = Provider<CloudBackup>((ref) {
  final b = CloudBackup(ref);
  ref.onDispose(b.dispose);
  return b;
});
