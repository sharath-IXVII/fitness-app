import 'package:intl/intl.dart';

/// A small group of friends who keep a streak together: a day counts only
/// when every member hits their daily goals. If one misses, the team's
/// streak (and its badge) is gone for everyone.
class Team {
  const Team({required this.id, required this.name, required this.members, required this.names, this.code});

  static const maxMembers = 6;

  final String id;
  final String name;
  final List<String> members;

  /// Member names by uid.
  final Map<String, String> names;
  final String? code;

  static Team fromJson(String id, Map<String, dynamic> j) => Team(
    id: id,
    name: j['name'] as String? ?? 'Team',
    members: [for (final m in j['members'] as List<dynamic>? ?? const []) m as String],
    names: {for (final e in (j['names'] as Map<String, dynamic>? ?? const {}).entries) e.key: e.value as String},
    code: j['code'] as String?,
  );
}

final _day = DateFormat('yyyy-MM-dd');
String teamDayKey(DateTime d) => _day.format(d);

/// Team badges by streak length.
const teamBadges = [(7, 'Bronze Squad'), (14, 'Silver Squad'), (30, 'Gold Squad'), (100, 'Legend Squad')];

/// The badge a team holds for a streak of [days], if any.
String? teamBadge(int days) {
  String? best;
  for (final (n, name) in teamBadges) {
    if (days >= n) best = name;
  }
  return best;
}

/// The team's streak: days in a row (to yesterday, plus today once
/// everyone is done) on which every member hit their goals. [done] maps a
/// day key to the uids who were done that day.
int teamStreak(List<String> members, Map<String, Set<String>> done, DateTime today) {
  if (members.length < 2) return 0;
  bool all(DateTime d) => (done[teamDayKey(d)] ?? const {}).containsAll(members);
  var d = DateTime(today.year, today.month, today.day);
  var n = 0;
  if (all(d)) n++;
  d = d.subtract(const Duration(days: 1));
  while (all(d)) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}
