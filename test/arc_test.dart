import 'package:fitalarm/features/arcs/domain/arc.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _active = DayScore({DailyTask.workout, DailyTask.water, DailyTask.steps});

Map<DateTime, DayScore> _activeDays(DateTime from, int days, {Set<int> skip = const {}}) => {
  for (var i = 0; i < days; i++)
    if (!skip.contains(i)) DateTime(from.year, from.month, from.day + i): _active,
};

void main() {
  test('the arc follows the calendar, three months each', () {
    expect(ArcPeriod.of(DateTime(2026, 10, 23)).label, 'Winter Arc 2026');
    expect(ArcPeriod.of(DateTime(2026, 12, 31)).season, Season.winter);
    expect(ArcPeriod.of(DateTime(2027, 1, 1)).label, 'Rise of Revolution 2027');
    expect(ArcPeriod.of(DateTime(2027, 5, 10)).season, Season.summer);
    expect(ArcPeriod.of(DateTime(2027, 9, 30)).season, Season.monsoon);

    final winter = ArcPeriod.of(DateTime(2026, 11, 1));
    expect(winter.start, DateTime(2026, 10));
    expect(winter.lastDay, DateTime(2026, 12, 31));
    expect(winter.totalDays, 92);
    expect(ArcPeriod.of(DateTime(2027, 2, 1)).previous, winter);
    expect(winter.badgeName(ArcTier.master), 'Master of Winter 2026');
  });

  test('badge tiers: survivor, warrior, master', () {
    final winter = ArcPeriod.of(DateTime(2026, 10, 1));
    final end = DateTime(2027, 1, 5);

    final all = ArcResult.of(winter, _activeDays(winter.start, 92), winter.start, end);
    expect(all.finished, isTrue);
    expect(all.earned, ArcTier.master);

    final missedOne = ArcResult.of(winter, _activeDays(winter.start, 92, skip: {40}), winter.start, end);
    expect(missedOne.earned, ArcTier.warrior);

    final sixty = ArcResult.of(winter, _activeDays(winter.start, 60), winter.start, end);
    expect(sixty.needed(ArcTier.survivor), 60);
    expect(sixty.needed(ArcTier.warrior), 80);
    expect(sixty.earned, ArcTier.survivor);

    final few = ArcResult.of(winter, _activeDays(winter.start, 20), winter.start, end);
    expect(few.earned, isNull);
  });

  test('joining mid-arc still allows every badge, counted from the first day', () {
    final winter = ArcPeriod.of(DateTime(2026, 10, 1));
    final joined = DateTime(2026, 10, 23);
    final today = DateTime(2026, 10, 25);
    final r = ArcResult.of(winter, _activeDays(joined, 3), joined, today);
    expect(r.eligible, 70); // 23 Oct – 31 Dec
    expect(r.active, 3);
    expect(r.reachable(ArcTier.master), isTrue);
    expect(r.target, ArcTier.master);
    expect(r.finished, isFalse);

    // Miss a day and Master is gone, Warrior is still on.
    final missed = ArcResult.of(winter, _activeDays(joined, 3, skip: {1}), joined, today);
    expect(missed.reachable(ArcTier.master), isFalse);
    expect(missed.target, ArcTier.warrior);
  });

  test('finished arcs leave badges behind', () {
    final first = DateTime(2026, 10, 1);
    final scores = {
      ..._activeDays(first, 92), // a perfect winter
      ..._activeDays(DateTime(2027, 1, 1), 50), // 50 of 90 days: not enough
    };
    final badges = earnedBadges(scores, first, DateTime(2027, 4, 10));
    expect(badges, hasLength(1));
    expect(badges.single.$1.label, 'Winter Arc 2026');
    expect(badges.single.$2, ArcTier.master);
  });

  test('five years of badges, and the best one is shown as a title', () {
    final all = arcCatalog();
    expect(all, hasLength(20));
    expect(all.first.label, 'Winter Arc 2026');
    expect(all[1].label, 'Rise of Revolution 2027');
    expect(all.last.label, 'Thunder Arc 2031');

    final winter = ArcPeriod.of(DateTime(2026, 10, 1));
    final spring = ArcPeriod.of(DateTime(2027, 1, 1));
    expect(bestBadge([]), isNull);
    expect(bestBadge([(spring, ArcTier.survivor), (winter, ArcTier.master)]), (winter, ArcTier.master));
  });
}
