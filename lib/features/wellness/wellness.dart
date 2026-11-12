import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';

/// One wellness entry: a breathing session, a breathing-rate check or a mood
/// check-in. Kept on the phone. FittArc is a wellness app: these are for the
/// user's own tracking and are never sorted as normal or abnormal.
class WellnessEntry {
  const WellnessEntry({required this.at, required this.kind, required this.value, this.extra = 0});

  final DateTime at;

  /// 'breathe' (minutes), 'rate' (breaths a minute) or 'mood' (1–5 mood,
  /// [extra] 1–5 energy).
  final String kind;
  final int value;
  final int extra;

  Map<String, dynamic> toJson() => {'at': at.millisecondsSinceEpoch, 'k': kind, 'v': value, 'e': extra};

  static WellnessEntry? fromJson(Map<String, dynamic> j) {
    try {
      return WellnessEntry(
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        kind: j['k'] as String,
        value: j['v'] as int,
        extra: j['e'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class WellnessNotifier extends Notifier<List<WellnessEntry>> {
  static const key = 'wellness.v1';

  @override
  List<WellnessEntry> build() {
    final raw = ref.read(sharedPrefsProvider).getString(key);
    if (raw == null) return const [];
    try {
      return [for (final j in jsonDecode(raw) as List) ?WellnessEntry.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String kind, int value, {int extra = 0}) async {
    // Keep about a year of entries.
    final next = [...state, WellnessEntry(at: clock.now(), kind: kind, value: value, extra: extra)];
    state = next.length > 1200 ? next.sublist(next.length - 1200) : next;
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode([for (final e in state) e.toJson()]));
  }
}

final wellnessProvider = NotifierProvider<WellnessNotifier, List<WellnessEntry>>(WellnessNotifier.new);

/// Breathing minutes in the last 7 days.
final calmMinutesWeekProvider = Provider<int>((ref) {
  final since = clock.now().subtract(const Duration(days: 7));
  return ref
      .watch(wellnessProvider)
      .where((e) => e.kind == 'breathe' && e.at.isAfter(since))
      .fold(0, (s, e) => s + e.value);
});

/// Breaths a minute from tap times (seconds from the start): the number of
/// breaths over the time between the first and last tap, scaled to a minute.
/// Null with fewer than three breaths.
int? breathsPerMinute(List<double> taps) {
  if (taps.length < 3) return null;
  final span = taps.last - taps.first;
  if (span <= 0) return null;
  return ((taps.length - 1) * 60 / span).round();
}
