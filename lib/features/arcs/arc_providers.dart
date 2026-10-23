import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../streaks/daily_log_providers.dart';
import '../streaks/domain/daily_log.dart';
import 'domain/arc.dart';

const _previewKey = 'arc.preview.v1';
const _firstUseKey = 'app.firstUse.v1';

/// Today's date, re-read when the app comes back to the foreground so the
/// arc (and the whole look) switches on the first day of a new arc.
class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dayOnly(DateTime.now());

  void refresh() {
    final now = dayOnly(DateTime.now());
    if (now != state) state = now;
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

/// A season chosen to preview its look; null follows the date.
class ArcPreviewNotifier extends Notifier<Season?> {
  @override
  Season? build() {
    final raw = ref.read(sharedPrefsProvider).getString(_previewKey);
    return raw == null ? null : Season.values.asNameMap()[raw];
  }

  Future<void> set(Season? s) async {
    state = s;
    final prefs = ref.read(sharedPrefsProvider);
    s == null ? await prefs.remove(_previewKey) : await prefs.setString(_previewKey, s.name);
  }
}

final arcPreviewProvider = NotifierProvider<ArcPreviewNotifier, Season?>(ArcPreviewNotifier.new);

/// The arc happening now.
final currentArcProvider = Provider<ArcPeriod>((ref) => ArcPeriod.of(ref.watch(todayProvider)));

/// The season whose look the app shows.
final themeSeasonProvider = Provider<Season>(
  (ref) => ref.watch(arcPreviewProvider) ?? ref.watch(currentArcProvider).season,
);

/// When the user started using the app: the first visit, or their earliest
/// log if that is older. Arc badges count from here.
final firstUseProvider = Provider<DateTime>((ref) {
  final prefs = ref.read(sharedPrefsProvider);
  final stored = DateTime.tryParse(prefs.getString(_firstUseKey) ?? '');
  DateTime first = stored ?? ref.read(todayProvider);
  if (stored == null) prefs.setString(_firstUseKey, first.toIso8601String());
  for (final d in ref.watch(dailyLogsProvider).keys) {
    if (d.isBefore(first)) first = d;
  }
  return dayOnly(first);
});

final currentArcResultProvider = Provider<ArcResult>(
  (ref) => ArcResult.of(
    ref.watch(currentArcProvider),
    ref.watch(dayScoresProvider),
    ref.watch(firstUseProvider),
    ref.watch(todayProvider),
  ),
);

/// Badges from finished arcs, newest first.
final arcBadgesProvider = Provider<List<(ArcPeriod, ArcTier)>>(
  (ref) => earnedBadges(ref.watch(dayScoresProvider), ref.watch(firstUseProvider), ref.watch(todayProvider)),
);

/// The badge shown as a title on the profile (and later to friends).
final bestBadgeProvider = Provider<(ArcPeriod, ArcTier)?>((ref) => bestBadge(ref.watch(arcBadgesProvider)));
