import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fitalarm/core/photo_store.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/clubs/clubs_providers.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:fitalarm/features/clubs/domain/run_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RunReport _report(String id, DateTime at) => RunReport(
  id: id,
  title: 'Run 5 km',
  clubName: 'Lake Runners',
  kind: ActivityKind.run,
  distanceM: 5000,
  timeMs: 27 * 60000,
  splitsMs: const [320000, 650000, 980000, 1300000, 1620000],
  route: const [(12.97, 77.59), (12.98, 77.59)],
  finishedAt: at,
  rank: 2,
  of: 9,
  xp: 100,
);

void main() {
  test('reports are removed 5 hours after the challenge', () async {
    final now = DateTime(2026, 11, 9, 18);
    SharedPreferences.setMockInitialValues({
      RunReportsNotifier.key: jsonEncode([
        _report('fresh', DateTime(2026, 11, 9, 16)).toJson(),
        _report('old', DateTime(2026, 11, 9, 12, 59)).toJson(),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    await withClock(Clock.fixed(now), () async {
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      expect(c.read(runReportsProvider).map((r) => r.id), ['fresh']);
      // The stored copy is cleaned too, so nothing piles up.
      expect((jsonDecode(prefs.getString(RunReportsNotifier.key)!) as List), hasLength(1));
      expect(c.read(runReportProvider('fresh'))!.expiresAt, DateTime(2026, 11, 9, 21));
    });
  });

  test('a report keeps its numbers and stays small', () {
    final r = _report('x', DateTime(2026, 11, 9, 7));
    final back = RunReport.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>)!;
    expect(back.lapMs, [320000, 330000, 330000, 320000, 320000]);
    expect(back.avgKmh, closeTo(11.1, 0.1));
    expect(back.rank, 2);
    // Even a long route is simplified to at most ~300 points (a few KB).
    final long = [
      for (var i = 0; i < 5000; i++) GpsFix(12.97 + i * 1e-5, 77.59, 5, DateTime(2026).add(Duration(seconds: i))),
    ];
    final simple = simplifyRoute(long);
    expect(simple.length, lessThanOrEqualTo(301));
    expect(simple.last, long.last.point);
    expect(jsonEncode(_report('y', DateTime(2026)).toJson()).length, lessThan(1000));
  });

  test('photos older than 30 days are deleted from the phone', () async {
    final dir = await Directory.systemTemp.createTemp('photos');
    addTearDown(() => dir.delete(recursive: true));
    final old = File('${dir.path}/old.jpg')..writeAsBytesSync([1, 2, 3]);
    final fresh = File('${dir.path}/new.jpg')..writeAsBytesSync([1, 2, 3]);
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 31)));
    final removed = await PhotoStore.deleteOlderThan(dir, DateTime.now().subtract(PhotoStore.keepFor));
    expect(removed, 1);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });
}
