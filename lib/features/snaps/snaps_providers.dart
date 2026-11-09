import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import 'domain/food_snap.dart';

const snapsKey = 'snaps.v1';

/// Food snaps, newest first. Kept on this phone only (no cloud storage); the
/// list keeps the last [keepDays] days.
class SnapsNotifier extends Notifier<List<FoodSnap>> {
  static const keepDays = 30;

  @override
  List<FoodSnap> build() {
    final raw = ref.read(sharedPrefsProvider).getString(snapsKey);
    if (raw == null) return const [];
    try {
      final from = clock.now().subtract(const Duration(days: keepDays));
      return [
        for (final j in jsonDecode(raw) as List<dynamic>)
          if (FoodSnap.fromJson(j as Map<String, dynamic>) case final s? when s.at.isAfter(from)) s,
      ]..sort((a, b) => b.at.compareTo(a.at));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() =>
      ref.read(sharedPrefsProvider).setString(snapsKey, jsonEncode([for (final s in state) s.toJson()]));

  Future<void> add(FoodSnap s) async {
    state = [s, ...state.where((o) => o.id != s.id)]..sort((a, b) => b.at.compareTo(a.at));
    await _save();
  }

  Future<void> remove(String id) async {
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
    await _save();
  }
}

final snapsProvider = NotifierProvider<SnapsNotifier, List<FoodSnap>>(SnapsNotifier.new);

/// One snap by id, or null.
final snapByIdProvider = Provider.family<FoodSnap?, String>(
  (ref, id) => ref.watch(snapsProvider).where((s) => s.id == id).firstOrNull,
);

/// Today's snaps, oldest first (breakfast before dinner).
final todaySnapsProvider = Provider<List<FoodSnap>>((ref) {
  final now = clock.now();
  bool today(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;
  return ref.watch(snapsProvider).where((s) => today(s.at)).toList().reversed.toList();
});
