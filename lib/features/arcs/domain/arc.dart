import 'package:flutter/material.dart';

import '../../../core/theme/palette.dart';
import '../../streaks/domain/daily_log.dart';

/// Falling or rising particles drawn behind every page.
enum ArcEffect { snow, embers, sun, rain }

/// The four three-month arcs of the year. The app's look follows the arc
/// for today's date, so it changes by itself without an update.
enum Season {
  winter(
    title: 'Winter Arc',
    months: 'Oct – Dec',
    firstMonth: 10,
    tagline: 'Lock in while everyone else hibernates.',
    palette: Palette.winter,
    icon: Icons.ac_unit_rounded,
    effect: ArcEffect.snow,
    tiers: ('Winter Survivor', 'Winter Warrior', 'Master of Winter'),
  ),
  revolution(
    title: 'Rise of Revolution',
    months: 'Jan – Mar',
    firstMonth: 1,
    tagline: 'New year. New you. Start the revolution.',
    palette: Palette.revolution,
    icon: Icons.local_fire_department_rounded,
    effect: ArcEffect.embers,
    tiers: ('Rebel', 'Revolutionary', 'Leader of the Revolution'),
  ),
  summer(
    title: 'Summer Arc',
    months: 'Apr – Jun',
    firstMonth: 4,
    tagline: 'Turn up the heat.',
    palette: Palette.summer,
    icon: Icons.wb_sunny_rounded,
    effect: ArcEffect.sun,
    tiers: ('Summer Survivor', 'Summer Warrior', 'Master of Summer'),
  ),
  monsoon(
    title: 'Monsoon Arc',
    months: 'Jul – Sep',
    firstMonth: 7,
    tagline: 'Train through the storm.',
    palette: Palette.monsoon,
    icon: Icons.thunderstorm_rounded,
    effect: ArcEffect.rain,
    tiers: ('Monsoon Survivor', 'Monsoon Warrior', 'Master of the Monsoon'),
  );

  const Season({
    required this.title,
    required this.months,
    required this.firstMonth,
    required this.tagline,
    required this.palette,
    required this.icon,
    required this.effect,
    required this.tiers,
  });

  final String title;
  final String months;
  final int firstMonth;
  final String tagline;
  final Palette palette;
  final IconData icon;
  final ArcEffect effect;

  /// Badge names for the three tiers, lowest first.
  final (String, String, String) tiers;

  static Season forMonth(int month) => switch (month) {
    >= 10 => winter,
    >= 7 => monsoon,
    >= 4 => summer,
    _ => revolution,
  };

  String tierName(ArcTier t) => switch (t) {
    ArcTier.survivor => tiers.$1,
    ArcTier.warrior => tiers.$2,
    ArcTier.master => tiers.$3,
  };
}

/// Badge levels: the share of the arc's days that must be active.
enum ArcTier {
  survivor(0.65, Color(0xFFC98B5A)),
  warrior(0.865, Color(0xFFB8C2CC)),
  master(1.0, Color(0xFFE2B33C));

  const ArcTier(this.share, this.ring);

  final double share;

  /// Bronze, silver, gold.
  final Color ring;
}

/// One arc in one year, e.g. Winter Arc 2026 (1 Oct – 31 Dec 2026).
class ArcPeriod {
  const ArcPeriod(this.season, this.year);

  factory ArcPeriod.of(DateTime d) => ArcPeriod(Season.forMonth(d.month), d.year);

  final Season season;
  final int year;

  DateTime get start => DateTime(year, season.firstMonth);

  /// The day after the arc ends.
  DateTime get end => DateTime(year, season.firstMonth + 3);

  DateTime get lastDay => DateTime(year, season.firstMonth + 3, 0);

  int get totalDays => _days(start, end);

  String get label => '${season.title} $year';

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  ArcPeriod get previous => ArcPeriod.of(DateTime(year, season.firstMonth - 1, 15));

  String badgeName(ArcTier t) => '${season.tierName(t)} $year';

  @override
  bool operator ==(Object other) => other is ArcPeriod && other.season == season && other.year == year;

  @override
  int get hashCode => Object.hash(season, year);
}

int _days(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// How someone is doing in an arc. Days only count from when they started
/// using the app, so joining mid-arc can still earn every badge.
class ArcResult {
  ArcResult({
    required this.period,
    required this.from,
    required this.active,
    required this.eligible,
    required this.remaining,
    required this.finished,
  });

  /// Scores [period] up to [today], counting from [firstUse].
  factory ArcResult.of(ArcPeriod period, Map<DateTime, DayScore> scores, DateTime firstUse, DateTime today) {
    final first = dayOnly(firstUse);
    final from = first.isAfter(period.start) ? first : period.start;
    final day = dayOnly(today);
    var active = 0;
    for (final e in scores.entries) {
      if (!e.key.isBefore(from) && e.key.isBefore(period.end) && !e.key.isAfter(day) && e.value.keepsStreak) {
        active++;
      }
    }
    final eligible = from.isBefore(period.end) ? _days(from, period.end) : 0;
    final finished = !day.isBefore(period.end);
    // Days still to come, today included unless it already counts.
    final todayDone = scores[day]?.keepsStreak ?? false;
    final remaining = finished ? 0 : _days(day, period.end) - (todayDone ? 1 : 0);
    return ArcResult(
      period: period,
      from: from,
      active: active,
      eligible: eligible,
      remaining: remaining,
      finished: finished,
    );
  }

  final ArcPeriod period;
  final DateTime from;

  /// Days with at least 3 of 5 goals.
  final int active;

  /// Days that count towards badges.
  final int eligible;

  /// Days left that could still become active.
  final int remaining;
  final bool finished;

  int needed(ArcTier t) => (t.share * eligible).ceil();

  /// The best badge already secured (it can't be lost any more).
  ArcTier? get earned {
    ArcTier? best;
    for (final t in ArcTier.values) {
      if (eligible > 0 && active >= needed(t)) best = t;
    }
    return best;
  }

  /// Whether [t] can still be reached.
  bool reachable(ArcTier t) => eligible > 0 && active + remaining >= needed(t);

  /// The highest badge still within reach.
  ArcTier? get target {
    for (final t in ArcTier.values.reversed) {
      if (reachable(t)) return t;
    }
    return null;
  }

  double get share => eligible == 0 ? 0 : active / eligible;
}

/// Badges from finished arcs since [firstUse], newest first.
List<(ArcPeriod, ArcTier)> earnedBadges(Map<DateTime, DayScore> scores, DateTime firstUse, DateTime today) {
  final out = <(ArcPeriod, ArcTier)>[];
  var p = ArcPeriod.of(today).previous;
  // Stop once arcs end before the user started.
  while (!p.end.isBefore(dayOnly(firstUse)) && out.length < 40) {
    final r = ArcResult.of(p, scores, firstUse, today);
    final t = r.earned;
    if (t != null) out.add((p, t));
    p = p.previous;
  }
  return out;
}

/// The first arc in the app.
const firstArc = ArcPeriod(Season.winter, 2026);

/// Five years of arcs, starting with [firstArc], oldest first.
List<ArcPeriod> arcCatalog({int years = 5}) {
  final out = <ArcPeriod>[];
  var p = firstArc;
  for (var i = 0; i < years * 4; i++) {
    out.add(p);
    p = ArcPeriod.of(p.end);
  }
  return out;
}

/// The badge to show next to someone's name: the highest tier, newest first.
(ArcPeriod, ArcTier)? bestBadge(List<(ArcPeriod, ArcTier)> earned) {
  (ArcPeriod, ArcTier)? best;
  for (final b in earned) {
    if (best == null || b.$2.index > best.$2.index) best = b;
  }
  return best;
}
