import '../../clubs/domain/club_challenge.dart';

/// A run, walk or ride someone did on their own, measured with GPS. Kept on
/// the phone.
class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.kind,
    required this.startedAt,
    required this.movingMs,
    required this.distanceM,
    this.route = const [],
    this.splitsMs = const [],
    this.steps = 0,
  });

  final String id;
  final ActivityKind kind;
  final DateTime startedAt;

  /// Time spent moving (pauses left out).
  final int movingMs;
  final int distanceM;
  final List<(double, double)> route;
  final List<int> splitsMs;

  /// Steps taken during a walk or run (0 for rides).
  final int steps;

  int get kcal => (distanceM / 1000 * kind.kcalPerKm).round();
  double get avgKmh => movingMs <= 0 ? 0 : distanceM / 1000 / (movingMs / 3600000);

  /// "Morning run", "Evening ride" …
  String get title {
    final h = startedAt.hour;
    final part = h < 12
        ? 'Morning'
        : h < 17
        ? 'Afternoon'
        : h < 21
        ? 'Evening'
        : 'Night';
    return '$part ${switch (kind) {
      ActivityKind.run => 'run',
      ActivityKind.walk => 'walk',
      ActivityKind.cycle => 'ride',
    }}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'k': kind.name,
    'at': startedAt.millisecondsSinceEpoch,
    'ms': movingMs,
    'd': distanceM,
    'r': [
      for (final (a, b) in route) [a, b],
    ],
    's': splitsMs,
    if (steps > 0) 'st': steps,
  };

  static ActivitySession? fromJson(Map<String, dynamic> j) {
    try {
      return ActivitySession(
        id: j['id'] as String,
        kind: ActivityKind.values.asNameMap()[j['k']] ?? ActivityKind.walk,
        startedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        movingMs: (j['ms'] as num).toInt(),
        distanceM: (j['d'] as num).toInt(),
        route: [
          for (final p in (j['r'] as List<dynamic>? ?? const []).cast<List<dynamic>>())
            ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        splitsMs: [for (final v in (j['s'] as List<dynamic>? ?? const [])) (v as num).toInt()],
        steps: (j['st'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Distance for a walk or run from both GPS and steps. GPS is used where it
/// worked; where it didn't (indoors, a treadmill, tall buildings), steps
/// times stride fill in, so a walk is never measured as 0 km. Rides use GPS
/// only. [strideM] is the walking stride; running strides are longer.
double fusedDistance({
  required ActivityKind kind,
  required double gpsMeters,
  required int steps,
  required double strideM,
}) {
  if (kind == ActivityKind.cycle) return gpsMeters;
  final stride = kind == ActivityKind.run ? strideM * runStrideFactor : strideM;
  final stepMeters = steps * stride;
  return gpsMeters > stepMeters ? gpsMeters : stepMeters;
}

/// A running stride is about a third longer than a walking one.
const runStrideFactor = 1.35;
