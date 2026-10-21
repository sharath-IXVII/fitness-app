import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import 'domain/routine.dart';

const _key = 'routines.v1';

/// Built-in presets followed by the user's custom routines.
class RoutinesNotifier extends Notifier<List<Routine>> {
  @override
  List<Routine> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    final custom = <Routine>[];
    if (raw != null) {
      try {
        for (final r in jsonDecode(raw) as List) {
          custom.add(Routine.fromJson(r as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    return [...Routine.presets, ...custom];
  }

  Future<void> save(Routine routine) async {
    final exists = state.any((r) => r.id == routine.id);
    state = exists ? [for (final r in state) r.id == routine.id ? routine : r] : [...state, routine];
    await _persist();
  }

  Future<void> delete(String id) async {
    state = state.where((r) => r.id != id || r.builtIn).toList();
    await _persist();
  }

  Future<void> _persist() => ref
      .read(sharedPrefsProvider)
      .setString(_key, jsonEncode([for (final r in state.where((r) => !r.builtIn)) r.toJson()]));
}

final routinesProvider = NotifierProvider<RoutinesNotifier, List<Routine>>(RoutinesNotifier.new);

/// Looks up a routine by id, falling back to the beginner preset if it was deleted.
Routine routineById(List<Routine> all, String id) => all.firstWhere((r) => r.id == id, orElse: () => Routine.beginner);
