import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import 'domain/health.dart';

const _key = 'health.readings.v1';

/// Every reading, oldest first. Kept on this phone only: it is not backed up
/// or uploaded, and it is wiped with the rest of the local data.
class HealthLogNotifier extends Notifier<List<HealthReading>> {
  /// Plenty for years of daily readings; the oldest go first beyond this.
  static const maxReadings = 3000;

  @override
  List<HealthReading> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final j in list) ?HealthReading.fromJson(j as Map<String, dynamic>),
      ]..sort((a, b) => a.at.compareTo(b.at));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() => ref.read(sharedPrefsProvider).setString(_key, jsonEncode([for (final r in state) r.toJson()]));

  Future<void> add(HealthReading r) async {
    final next = [...state, r]..sort((a, b) => a.at.compareTo(b.at));
    state = next.length > maxReadings ? next.sublist(next.length - maxReadings) : next;
    await _save();
  }

  Future<void> remove(String id) async {
    state = [
      for (final r in state)
        if (r.id != id) r,
    ];
    await _save();
  }
}

final healthLogProvider = NotifierProvider<HealthLogNotifier, List<HealthReading>>(HealthLogNotifier.new);

/// Readings of one kind, newest first.
final readingsOfProvider = Provider.family<List<HealthReading>, ReadingKind>((ref, kind) {
  return [
    for (final r in ref.watch(healthLogProvider).reversed)
      if (r.kind == kind) r,
  ];
});

/// The last week of blood pressure, averaged the way guidelines advise.
final homeBpProvider = Provider<HomeBpSummary>((ref) => homeBpSummary(ref.watch(healthLogProvider), clock.now()));
