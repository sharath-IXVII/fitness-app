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

  /// Puts [blocks] (their times and details) on [days], replacing whatever
  /// those days had. Other days are left alone.
  Future<void> putOnDays(List<DayBlock> blocks, Set<int> days) async {
    if (days.isEmpty) return;
    final kept = [
      for (final b in state)
        if (!b.days.every(days.contains)) b.copyWith(days: b.days.difference(days)),
    ];
    var id = [...kept, ...state].fold(0, (m, b) => b.id > m ? b.id : m);
    await _set([
      ...kept,
      for (final b in blocks) b.copyWith(id: ++id, days: {...days}),
    ]);
  }

  /// Copies everything on [from] to [to].
  Future<void> copyDay(int from, Set<int> to) => putOnDays(blocksFor(state, from), to.difference({from}));

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

/// A day plan the user saved under their own name.
class MyTemplate {
  const MyTemplate(this.name, this.blocks);

  final String name;
  final List<DayBlock> blocks;

  Map<String, dynamic> toJson() => {
    'name': name,
    'blocks': [for (final b in blocks) b.toJson()],
  };

  factory MyTemplate.fromJson(Map<String, dynamic> j) => MyTemplate(j['name'] as String, [
    for (final b in j['blocks'] as List) DayBlock.fromJson(b as Map<String, dynamic>),
  ]);
}

class MyTemplatesNotifier extends Notifier<List<MyTemplate>> {
  static const _tKey = 'myday.templates.v1';

  @override
  List<MyTemplate> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_tKey);
    if (raw == null) return const [];
    try {
      return [for (final t in jsonDecode(raw) as List) MyTemplate.fromJson(t as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  /// Saves [blocks] as [name]; a template with the same name is replaced.
  Future<void> save(String name, List<DayBlock> blocks) => _set([
    for (final t in state)
      if (t.name.toLowerCase() != name.trim().toLowerCase()) t,
    MyTemplate(name.trim(), [for (final b in blocks) b.copyWith(days: const {})]),
  ]);

  Future<void> delete(String name) => _set([
    for (final t in state)
      if (t.name != name) t,
  ]);

  Future<void> _set(List<MyTemplate> list) async {
    state = list;
    await ref.read(sharedPrefsProvider).setString(_tKey, jsonEncode([for (final t in list) t.toJson()]));
  }
}

final myTemplatesProvider = NotifierProvider<MyTemplatesNotifier, List<MyTemplate>>(MyTemplatesNotifier.new);

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
    // "Done" from a notification is written by a background isolate; start
    // from what's stored, not a stale copy.
    final prefs = ref.read(sharedPrefsProvider);
    try {
      await prefs.reload();
    } catch (_) {}
    final raw = prefs.getString(_key);
    final next = raw == null ? <int>{} : (jsonDecode(raw) as List).cast<int>().toSet();
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(next.toList()));
  }
}

final doneTodayProvider = NotifierProvider<DoneTodayNotifier, Set<int>>(DoneTodayNotifier.new);
