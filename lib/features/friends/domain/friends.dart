import 'dart:math';

import '../../workout/domain/exercise.dart';

/// What friends can see about someone: name, badge title, XP and how this
/// arc is going. Nothing else from the phone is shared.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.name,
    this.title,
    this.titleTier,
    this.titleSeason,
    this.level = 1,
    this.xp = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.arcLabel = '',
    this.arcActive = 0,
    this.workoutsWeek = 0,
  });

  final String uid;
  final String name;

  /// Best arc badge, e.g. "Master of Winter 2026".
  final String? title;

  /// 0 survivor, 1 warrior, 2 master.
  final int? titleTier;

  /// Season name of the badge (for its medal).
  final String? titleSeason;
  final int level;
  final int xp;
  final int streak;
  final int bestStreak;

  /// The arc happening now and the user's active days in it.
  final String arcLabel;
  final int arcActive;

  /// Guided workouts finished this week.
  final int workoutsWeek;

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': title,
    'titleTier': titleTier,
    'titleSeason': titleSeason,
    'level': level,
    'xp': xp,
    'streak': streak,
    'bestStreak': bestStreak,
    'arcLabel': arcLabel,
    'arcActive': arcActive,
    'workoutsWeek': workoutsWeek,
  };

  factory PublicProfile.fromJson(String uid, Map<String, dynamic> j) => PublicProfile(
    uid: uid,
    name: j['name'] as String? ?? 'Friend',
    title: j['title'] as String?,
    titleTier: j['titleTier'] as int?,
    titleSeason: j['titleSeason'] as String?,
    level: j['level'] as int? ?? 1,
    xp: j['xp'] as int? ?? 0,
    streak: j['streak'] as int? ?? 0,
    bestStreak: j['bestStreak'] as int? ?? 0,
    arcLabel: j['arcLabel'] as String? ?? '',
    arcActive: j['arcActive'] as int? ?? 0,
    workoutsWeek: j['workoutsWeek'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) => other is PublicProfile && other.uid == uid && _mapEq(other.toJson(), toJson());

  @override
  int get hashCode => Object.hash(uid, name, xp, streak, title, arcActive, workoutsWeek);

  static bool _mapEq(Map a, Map b) => a.length == b.length && a.keys.every((k) => a[k] == b[k]);
}

enum ChallengeStatus { open, accepted, done, declined }

/// "I'm challenging you to 10 push-ups." Both do it, verified by the camera;
/// once both are done they become friends.
class FriendChallenge {
  const FriendChallenge({
    required this.id,
    required this.code,
    required this.fromUid,
    required this.fromName,
    required this.exercise,
    required this.reps,
    required this.arcLabel,
    required this.createdAt,
    this.fromTitle,
    this.toUid,
    this.toName,
    this.toTitle,
    this.status = ChallengeStatus.open,
    this.fromDone = false,
    this.toDone = false,
  });

  final String id;

  /// Six letters to share; anyone with it can join while it's open.
  final String code;
  final String fromUid;
  final String fromName;
  final String? fromTitle;
  final String? toUid;
  final String? toName;
  final String? toTitle;
  final Exercise exercise;

  /// Reps, or seconds for timed exercises (plank, wall sit).
  final int reps;
  final String arcLabel;
  final ChallengeStatus status;
  final bool fromDone;
  final bool toDone;
  final DateTime createdAt;

  bool isMine(String uid) => fromUid == uid;
  bool involves(String uid) => fromUid == uid || toUid == uid;
  bool doneBy(String uid) => uid == fromUid ? fromDone : (uid == toUid && toDone);
  String? otherName(String uid) => uid == fromUid ? toName : fromName;
  String? otherUid(String uid) => uid == fromUid ? toUid : fromUid;

  /// "10 push-ups" or "30s plank".
  String get task => '${exercise.formatTarget(reps)} ${exercise.label.toLowerCase()}';

  /// The message shared on WhatsApp, Instagram, …
  String inviteMessage(String storeUrl) {
    final who = fromTitle == null ? fromName : '$fromName, $fromTitle';
    return "I'm challenging you to $task for the $arcLabel! 💪\n"
        '— $who\n\n'
        'Get Fit Tracker, open Friends → Enter code and type $code. '
        'Finish it and we become friends on the leaderboard.\n$storeUrl';
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'fromUid': fromUid,
    'fromName': fromName,
    'fromTitle': fromTitle,
    'toUid': toUid,
    'toName': toName,
    'toTitle': toTitle,
    'exercise': exercise.name,
    'reps': reps,
    'arcLabel': arcLabel,
    'status': status.name,
    'fromDone': fromDone,
    'toDone': toDone,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory FriendChallenge.fromJson(String id, Map<String, dynamic> j) => FriendChallenge(
    id: id,
    code: j['code'] as String,
    fromUid: j['fromUid'] as String,
    fromName: j['fromName'] as String? ?? 'Friend',
    fromTitle: j['fromTitle'] as String?,
    toUid: j['toUid'] as String?,
    toName: j['toName'] as String?,
    toTitle: j['toTitle'] as String?,
    exercise: Exercise.values.asNameMap()[j['exercise']] ?? Exercise.pushUp,
    reps: j['reps'] as int? ?? 10,
    arcLabel: j['arcLabel'] as String? ?? '',
    status: ChallengeStatus.values.asNameMap()[j['status']] ?? ChallengeStatus.open,
    fromDone: j['fromDone'] as bool? ?? false,
    toDone: j['toDone'] as bool? ?? false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int? ?? 0),
  );
}

/// Exercises a challenge can use: ones the camera can count, so nobody can
/// just claim they did it.
const challengeExercises = [
  Exercise.pushUp,
  Exercise.squat,
  Exercise.sitUp,
  Exercise.jumpingJack,
  Exercise.lunge,
  Exercise.burpee,
  Exercise.plank,
  Exercise.highKnees,
];

/// Easy-to-read share codes: no 0/O or 1/I/L.
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String newChallengeCode([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes([for (var i = 0; i < 6; i++) _alphabet.codeUnitAt(r.nextInt(_alphabet.length))]);
}

/// Tidies what someone typed: "k7q 2mx" → "K7Q2MX".
String normalizeCode(String typed) => typed.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
