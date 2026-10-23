import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import 'domain/plans.dart';

const _key = 'training.v1';

/// A finished guided workout.
class WorkoutRecord {
  const WorkoutRecord({required this.title, required this.at, required this.seconds, required this.kcal});

  final String title;
  final DateTime at;
  final int seconds;
  final int kcal;

  Map<String, dynamic> toJson() => {'title': title, 'at': at.toIso8601String(), 'seconds': seconds, 'kcal': kcal};

  factory WorkoutRecord.fromJson(Map<String, dynamic> j) => WorkoutRecord(
    title: j['title'] as String,
    at: DateTime.parse(j['at'] as String),
    seconds: j['seconds'] as int,
    kcal: j['kcal'] as int,
  );
}

/// How far the user is in one 30-day challenge.
class ChallengeProgress {
  const ChallengeProgress({required this.level, this.done = const {}});

  final Level level;

  /// Completed days, rest days included.
  final Set<int> done;

  /// The next day to do (1–30), or null when the challenge is finished.
  int? get nextDay {
    for (var d = 1; d <= Challenge.days; d++) {
      if (!done.contains(d)) return d;
    }
    return null;
  }

  double get fraction => done.length / Challenge.days;

  Map<String, dynamic> toJson() => {'level': level.name, 'done': done.toList()..sort()};

  factory ChallengeProgress.fromJson(Map<String, dynamic> j) => ChallengeProgress(
    level: Level.values.byName(j['level'] as String),
    done: {for (final d in j['done'] as List) d as int},
  );
}

class TrainingState {
  const TrainingState({this.challenges = const {}, this.history = const [], this.voice = true});

  final Map<String, ChallengeProgress> challenges;

  /// Newest first.
  final List<WorkoutRecord> history;

  /// Spoken cues during workouts.
  final bool voice;

  TrainingState copyWith({Map<String, ChallengeProgress>? challenges, List<WorkoutRecord>? history, bool? voice}) =>
      TrainingState(
        challenges: challenges ?? this.challenges,
        history: history ?? this.history,
        voice: voice ?? this.voice,
      );

  Map<String, dynamic> toJson() => {
    'challenges': {for (final e in challenges.entries) e.key: e.value.toJson()},
    'history': [for (final h in history) h.toJson()],
    'voice': voice,
  };

  factory TrainingState.fromJson(Map<String, dynamic> j) => TrainingState(
    challenges: {
      for (final e in (j['challenges'] as Map? ?? {}).entries)
        e.key as String: ChallengeProgress.fromJson(e.value as Map<String, dynamic>),
    },
    history: [for (final h in j['history'] as List? ?? []) WorkoutRecord.fromJson(h as Map<String, dynamic>)],
    voice: j['voice'] as bool? ?? true,
  );

  /// Workouts and minutes since Monday.
  ({int workouts, int minutes, int kcal}) thisWeek(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final week = history.where((h) => !h.at.isBefore(monday));
    return (
      workouts: week.length,
      minutes: (week.fold(0, (a, h) => a + h.seconds) / 60).round(),
      kcal: week.fold(0, (a, h) => a + h.kcal),
    );
  }
}

class TrainingNotifier extends Notifier<TrainingState> {
  /// History is capped so storage stays small.
  static const maxHistory = 200;

  @override
  TrainingState build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const TrainingState();
    try {
      return TrainingState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TrainingState();
    }
  }

  Future<void> _set(TrainingState s) async {
    state = s;
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(s.toJson()));
  }

  Future<void> startChallenge(String id, Level level) => _set(
    state.copyWith(
      challenges: {
        ...state.challenges,
        id: ChallengeProgress(level: level),
      },
    ),
  );

  Future<void> quitChallenge(String id) => _set(state.copyWith(challenges: {...state.challenges}..remove(id)));

  Future<void> completeDay(String id, int day) async {
    final p = state.challenges[id];
    if (p == null) return;
    await _set(
      state.copyWith(
        challenges: {
          ...state.challenges,
          id: ChallengeProgress(level: p.level, done: {...p.done, day}),
        },
      ),
    );
  }

  Future<void> record(WorkoutRecord r) =>
      _set(state.copyWith(history: [r, ...state.history].take(maxHistory).toList()));

  Future<void> setVoice(bool on) => _set(state.copyWith(voice: on));
}

final trainingProvider = NotifierProvider<TrainingNotifier, TrainingState>(TrainingNotifier.new);
