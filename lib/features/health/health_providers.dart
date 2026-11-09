import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import 'domain/health.dart';
import 'domain/live_hr.dart';

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
      return [for (final j in list) ?HealthReading.fromJson(j as Map<String, dynamic>)]
        ..sort((a, b) => a.at.compareTo(b.at));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() =>
      ref.read(sharedPrefsProvider).setString(_key, jsonEncode([for (final r in state) r.toJson()]));

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

const _arcKey = 'health.arc.v1';

/// Arc minutes earned from live heart-rate sessions, by day. Kept on this
/// phone only.
class ArcMinutesNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_arcKey);
    if (raw == null) return const {};
    try {
      return {for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble()};
    } catch (_) {
      return const {};
    }
  }

  Future<void> add(DateTime day, double arc) async {
    if (arc <= 0) return;
    final k = dayKey(day);
    final next = {...state, k: (state[k] ?? 0) + arc};
    // A year is plenty; older days are dropped.
    final keys = next.keys.toList()..sort();
    for (final old in keys.take((keys.length - 366).clamp(0, keys.length))) {
      next.remove(old);
    }
    state = next;
    await ref.read(sharedPrefsProvider).setString(_arcKey, jsonEncode(state));
  }
}

final arcMinutesProvider = NotifierProvider<ArcMinutesNotifier, Map<String, double>>(ArcMinutesNotifier.new);

/// Arc minutes over the last seven days.
final weekArcProvider = Provider<double>((ref) => weekArcMinutes(ref.watch(arcMinutesProvider), clock.now()));
