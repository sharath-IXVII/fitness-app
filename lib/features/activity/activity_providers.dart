import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import 'domain/activity_session.dart';

/// Runs, walks and rides, newest first. On this phone; the last 100 are kept.
class ActivitiesNotifier extends Notifier<List<ActivitySession>> {
  static const key = 'activities.v1';
  static const keep = 100;

  @override
  List<ActivitySession> build() {
    final raw = ref.read(sharedPrefsProvider).getString(key);
    if (raw == null) return const [];
    try {
      return [for (final j in jsonDecode(raw) as List<dynamic>) ?ActivitySession.fromJson(j as Map<String, dynamic>)]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(ActivitySession s) async {
    state = [s, ...state.where((o) => o.id != s.id)].take(keep).toList();
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode([for (final a in state) a.toJson()]));
  }

  Future<void> remove(String id) async {
    state = [
      for (final a in state)
        if (a.id != id) a,
    ];
    await ref.read(sharedPrefsProvider).setString(key, jsonEncode([for (final a in state) a.toJson()]));
  }
}

final activitiesProvider = NotifierProvider<ActivitiesNotifier, List<ActivitySession>>(ActivitiesNotifier.new);
