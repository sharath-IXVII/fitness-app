import 'club_challenge.dart';

/// A member's own performance report for one finished challenge. Kept on
/// their phone for [keepFor], unless they download it.
class RunReport {
  const RunReport({
    required this.id,
    required this.title,
    required this.clubName,
    required this.kind,
    required this.distanceM,
    required this.timeMs,
    required this.splitsMs,
    required this.route,
    required this.finishedAt,
    this.rank,
    this.of,
    this.xp = 0,
  });

  static const keepFor = Duration(hours: 5);

  /// The challenge id.
  final String id;
  final String title;
  final String clubName;
  final ActivityKind kind;
  final int distanceM;
  final int timeMs;

  /// Time at each full km, from the start (ms).
  final List<int> splitsMs;

  /// The route, simplified, as (latitude, longitude).
  final List<(double, double)> route;
  final DateTime finishedAt;

  /// Place in the club ranking, and out of how many.
  final int? rank;
  final int? of;
  final int xp;

  DateTime get expiresAt => finishedAt.add(keepFor);
  bool expired(DateTime now) => !now.isBefore(expiresAt);

  double get avgKmh => timeMs <= 0 ? 0 : distanceM / 1000 / (timeMs / 3600000);
  int get kcal => (distanceM / 1000 * kind.kcalPerKm).round();

  /// Time for each km on its own (ms).
  List<int> get lapMs => [for (var i = 0; i < splitsMs.length; i++) splitsMs[i] - (i == 0 ? 0 : splitsMs[i - 1])];

  Map<String, dynamic> toJson() => {
    'id': id,
    't': title,
    'c': clubName,
    'k': kind.name,
    'd': distanceM,
    'ms': timeMs,
    's': splitsMs,
    'r': [
      for (final (a, b) in route) [a, b],
    ],
    'at': finishedAt.millisecondsSinceEpoch,
    if (rank != null) 'rank': rank,
    if (of != null) 'of': of,
    'xp': xp,
  };

  static RunReport? fromJson(Map<String, dynamic> j) {
    try {
      return RunReport(
        id: j['id'] as String,
        title: j['t'] as String,
        clubName: j['c'] as String? ?? '',
        kind: ActivityKind.values.asNameMap()[j['k']] ?? ActivityKind.run,
        distanceM: (j['d'] as num).toInt(),
        timeMs: (j['ms'] as num).toInt(),
        splitsMs: [for (final v in j['s'] as List<dynamic>) (v as num).toInt()],
        route: [
          for (final p in (j['r'] as List<dynamic>).cast<List<dynamic>>())
            ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        finishedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        rank: (j['rank'] as num?)?.toInt(),
        of: (j['of'] as num?)?.toInt(),
        xp: (j['xp'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Keeps every [step]th point (and the last), at most about [max] points.
List<(double, double)> simplifyRoute(List<GpsFix> route, {int max = 300}) {
  if (route.length <= max) return [for (final f in route) f.point];
  final step = route.length / max;
  return [for (var i = 0.0; i < route.length - 1; i += step) route[i.floor()].point, route.last.point];
}
