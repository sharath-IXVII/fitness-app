import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../arcs/arc_providers.dart';
import '../friends/friends_providers.dart';
import 'domain/festival.dart';

const _cacheKey = 'festivals.config.v1';

/// Extra or corrected festival dates from Firestore (config/festivals), so
/// new festivals appear without an app update. The last copy is kept on the
/// phone for offline days.
final festivalConfigProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final prefs = ref.read(sharedPrefsProvider);
  Map<String, dynamic>? cached;
  try {
    final raw = prefs.getString(_cacheKey);
    if (raw != null) cached = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {}
  yield cached;
  final db = ref.watch(friendsBackendProvider)?.db;
  if (db == null) return;
  try {
    await for (final snap in db.collection('config').doc('festivals').snapshots()) {
      final data = snap.data();
      if (data != null) await prefs.setString(_cacheKey, jsonEncode(data));
      yield data ?? cached;
    }
  } catch (_) {
    // Offline or not allowed: the built-in dates still work.
  }
});

/// The festival happening today, if any.
final festivalProvider = Provider<Festival?>((ref) {
  final config = parseFestivalConfig(ref.watch(festivalConfigProvider).value);
  return festivalOn(ref.watch(todayProvider), extra: config.dates, custom: config.custom);
});
