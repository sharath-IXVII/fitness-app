import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reminders.dart';
import '../../core/storage.dart';
import 'domain/day_block.dart';

const _key = 'myday.v1';
const _remindKey = 'myday.remind.v1';

class MyDayNotifier extends Notifier<List<DayBlock>> {
  @override
  List<DayBlock> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [for (final b in jsonDecode(raw) as List) DayBlock.fromJson(b as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  int get _nextId => state.fold(0, (m, b) => b.id > m ? b.id : m) + 1;

  DayBlock draft({required int weekday}) => DayBlock(
    id: _nextId,
    kind: BlockKind.custom,
    time: TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: 0),
    days: {weekday},
  );

  Future<void> applyTemplate(RoutineTemplate t, TimeOfDay wake, TimeOfDay sleep) => _set(t.build(wake, sleep));

  Future<void> save(DayBlock b) async {
    final exists = state.any((x) => x.id == b.id);
    await _set(exists ? [for (final x in state) x.id == b.id ? b : x] : [...state, b]);
  }

  Future<void> delete(int id) => _set(state.where((b) => b.id != id).toList());

  Future<void> restore(DayBlock b) => save(b);

  Future<void> clear() => _set(const []);

  Future<void> _set(List<DayBlock> blocks) async {
    state = blocks;
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode([for (final b in blocks) b.toJson()]));
    await reschedule();
  }

  Future<void> reschedule() => Reminders.scheduleBlocks(state, enabled: ref.read(myDayRemindersProvider));
}

final myDayProvider = NotifierProvider<MyDayNotifier, List<DayBlock>>(MyDayNotifier.new);

/// Master switch for My Day reminders.
class MyDayRemindersNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_remindKey) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPrefsProvider).setBool(_remindKey, on);
    if (on) await Reminders.requestPermission();
    await ref.read(myDayProvider.notifier).reschedule();
  }
}

final myDayRemindersProvider = NotifierProvider<MyDayRemindersNotifier, bool>(MyDayRemindersNotifier.new);

/// Ids of blocks marked done today (from the app or a notification action).
class DoneTodayNotifier extends Notifier<Set<int>> {
  String get _key => ReminderKeys.done(DateTime.now());

  @override
  Set<int> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    return raw == null ? {} : (jsonDecode(raw) as List).cast<int>().toSet();
  }

  Future<void> toggle(int id) async {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(next.toList()));
  }
}

final doneTodayProvider = NotifierProvider<DoneTodayNotifier, Set<int>>(DoneTodayNotifier.new);
