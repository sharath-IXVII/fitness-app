import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/myday/domain/day_block.dart';
import 'package:fitalarm/features/myday/myday_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> make() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  }

  DayBlock b(int id, BlockKind k, int h, Set<int> days) =>
      DayBlock(id: id, kind: k, time: TimeOfDay(hour: h, minute: 0), days: days, remind: false);

  test('copy Monday to Wednesday replaces Wednesday only', () async {
    final c = await make();
    final n = c.read(myDayProvider.notifier);
    await n.save(b(1, BlockKind.workout, 6, {1}));
    await n.save(b(2, BlockKind.lunch, 13, {1}));
    await n.save(b(3, BlockKind.study, 9, {3, 5}));
    await n.copyDay(1, {3});
    final s = c.read(myDayProvider);
    expect(blocksFor(s, 3).map((x) => x.kind), [BlockKind.workout, BlockKind.lunch]);
    expect(blocksFor(s, 1).map((x) => x.kind), [BlockKind.workout, BlockKind.lunch]);
    expect(blocksFor(s, 5).map((x) => x.kind), [BlockKind.study]);
    expect(s.map((x) => x.id).toSet().length, s.length);
  });

  test('own template saves and applies to chosen days', () async {
    final c = await make();
    final n = c.read(myDayProvider.notifier);
    await n.save(b(1, BlockKind.workout, 6, {1}));
    await c.read(myTemplatesProvider.notifier).save('Gym day', blocksFor(c.read(myDayProvider), 1));
    final t = c.read(myTemplatesProvider).single;
    expect(t.name, 'Gym day');
    await n.putOnDays(t.blocks, {2, 4, 6});
    for (final d in [1, 2, 4, 6]) {
      expect(blocksFor(c.read(myDayProvider), d).single.kind, BlockKind.workout);
    }
    expect(blocksFor(c.read(myDayProvider), 3), isEmpty);
    // Survives a restart.
    final again = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance())],
    );
    expect(again.read(myTemplatesProvider).single.blocks.single.kind, BlockKind.workout);
  });
}
