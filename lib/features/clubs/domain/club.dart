import 'package:flutter/material.dart';

/// What a club is about. Shown as an icon and used to filter.
enum ClubKind {
  gym('Gym', Icons.fitness_center_rounded),
  running('Running', Icons.directions_run_rounded),
  walking('Walking', Icons.directions_walk_rounded),
  cycling('Cycling', Icons.directions_bike_rounded),
  yoga('Yoga', Icons.self_improvement_rounded),
  sports('Sports', Icons.sports_cricket_rounded),
  diet('Diet', Icons.restaurant_rounded),
  other('Other', Icons.groups_rounded);

  const ClubKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A club anyone can create and anyone can join.
class Club {
  const Club({
    required this.id,
    required this.name,
    required this.about,
    required this.kind,
    required this.ownerUid,
    required this.ownerName,
    this.code,
  });

  final String id;
  final String name;
  final String about;
  final ClubKind kind;
  final String ownerUid;
  final String ownerName;

  /// The invite code people type to find this club, e.g. "K7Q2MX".
  final String? code;

  static Club fromJson(String id, Map<String, dynamic> j) => Club(
    id: id,
    name: j['name'] as String? ?? 'Club',
    about: j['about'] as String? ?? '',
    kind: ClubKind.values.asNameMap()[j['kind']] ?? ClubKind.other,
    ownerUid: j['ownerUid'] as String? ?? '',
    ownerName: j['ownerName'] as String? ?? '',
    code: j['code'] as String?,
  );
}

/// One chat message. Messages disappear 24 hours after they are sent.
class ClubMessage {
  const ClubMessage({required this.id, required this.uid, required this.name, required this.text, required this.at});

  static const lifetime = Duration(hours: 24);

  final String id;
  final String uid;
  final String name;
  final String text;
  final DateTime at;

  bool expired(DateTime now) => now.difference(at) >= lifetime;
}

/// Limits, the same as in firestore.rules.
abstract final class ClubLimits {
  static const name = (3, 40);
  static const about = 200;
  static const message = 500;
}

/// Web links, app invite links and bare domains ("x.com", "wa.me/…") are not
/// allowed in clubs. firestore.rules checks the same pattern on the server.
final _link = RegExp(
  r'(https?://|www\.|wa\.me|t\.me|[a-z0-9-]+\.(com|in|net|org|io|co|me|ly|app|xyz|link|gg|info|biz|online|site|shop|club|tv|to)([^a-z0-9]|$))',
  caseSensitive: false,
);

bool containsLink(String text) => _link.hasMatch(text);

/// Why [text] can't be sent, or null when it's fine.
String? messageProblem(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Type a message.';
  if (t.length > ClubLimits.message) return 'Keep it under ${ClubLimits.message} characters.';
  if (containsLink(t)) return 'Links are not allowed in clubs.';
  return null;
}

/// Why a club can't be created with these details, or null.
String? clubProblem(String name, String about) {
  final n = name.trim();
  if (n.length < ClubLimits.name.$1) return 'Give the club a name of at least ${ClubLimits.name.$1} letters.';
  if (n.length > ClubLimits.name.$2) return 'Keep the name under ${ClubLimits.name.$2} characters.';
  if (about.trim().length > ClubLimits.about) return 'Keep the description under ${ClubLimits.about} characters.';
  if (containsLink(n) || containsLink(about)) return 'Links are not allowed in clubs.';
  return null;
}
