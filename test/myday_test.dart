import 'package:fitalarm/core/reminders.dart';
import 'package:fitalarm/features/myday/domain/day_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DayBlock _b(int id, int h, int m, {int minutes = 0, Set<int> days = const {1, 2, 3, 4, 5, 6, 7}}) => DayBlock(
  id: id,
  kind: BlockKind.custom,
  time: TimeOfDay(hour: h, minute: m),
  minutes: minutes,
  days: days,
);

void main() {
  test('blocks are filtered by weekday and sorted by time', () {
    final all = [
      _b(1, 13, 0),
      _b(2, 7, 0),
      _b(3, 9, 0, days: {1, 2, 3, 4, 5}),
    ];
    expect(blocksFor(all, 1).map((b) => b.id), [2, 3, 1]);
    expect(blocksFor(all, 7).map((b) => b.id), [2, 1]);
  });

  test('current-or-next picks the running block, then the next one', () {
    final day = [_b(1, 9, 0, minutes: 120), _b(2, 13, 0), _b(3, 18, 0)];
    expect(currentOrNext(day, 8 * 60)!.id, 1);
    expect(currentOrNext(day, 10 * 60)!.id, 1, reason: 'work block still running');
    expect(currentOrNext(day, 11 * 60 + 30)!.id, 2);
    expect(currentOrNext(day, 19 * 60), isNull);
  });

  test('every template builds a valid, uniquely-identified plan', () {
    for (final t in RoutineTemplate.values) {
      final blocks = t.build(const TimeOfDay(hour: 6, minute: 30), const TimeOfDay(hour: 22, minute: 30));
      expect(blocks, isNotEmpty, reason: t.label);
      expect(blocks.map((b) => b.id).toSet(), hasLength(blocks.length), reason: t.label);
      for (final b in blocks) {
        expect(b.time.hour, inInclusiveRange(0, 23));
        expect(b.days, isNotEmpty);
      }
      expect(blocks.any((b) => b.kind == BlockKind.workout), isTrue, reason: '${t.label} includes a workout');
    }
  });

  test('json round-trip and lead-time reminder minute', () {
    final b = _b(5, 18, 0, minutes: 45).copyWith(leadMinutes: 10, title: 'Gym', days: {1, 3});
    expect(DayBlock.fromJson(b.toJson()).toJson(), b.toJson());
    expect(b.remindMinute, 18 * 60 - 10);
    expect(b.name, 'Gym');
    expect(_b(6, 9, 0).name, 'Custom');
  });

  test('water reminder slots stay inside waking hours', () {
    final slots = Reminders.waterSlots(const TimeOfDay(hour: 7, minute: 0), const TimeOfDay(hour: 22, minute: 0), 90);
    expect(slots.first, 8 * 60);
    expect(slots.last, lessThanOrEqualTo(21 * 60));
    expect(slots.length, 9);
    expect(Reminders.waterSlots(const TimeOfDay(hour: 7, minute: 0), const TimeOfDay(hour: 8, minute: 0), 60), isEmpty);
  });
}
