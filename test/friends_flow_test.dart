import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/core/widgets/gradient_button.dart';
import 'package:fitalarm/features/clubs/clubs_backend.dart';
import 'package:fitalarm/features/clubs/domain/club.dart';
import 'package:fitalarm/features/clubs/domain/club_challenge.dart';
import 'package:fitalarm/features/clubs/gps.dart';
import 'package:fitalarm/features/friends/domain/friends.dart';
import 'package:fitalarm/features/friends/friends_backend.dart';
import 'package:fitalarm/features/friends/friends_providers.dart';
import 'package:fitalarm/features/workout/domain/exercise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _wait(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Map<String, Object> _seed() => {
  'auth.demo.v1': jsonEncode({'uid': 'demo', 'method': 'phone', 'phone': '+919876543210'}),
  'profile.v1': jsonEncode({
    'name': 'Asha',
    'gender': 'female',
    'age': 24,
    'heightCm': 162,
    'weightKg': 64,
    'goal': 'maintain',
    'activity': 'light',
    'diet': 'veg',
    'level': 'beginner',
    'wake': 390,
    'sleep': 1380,
  }),
};

Future<FriendsBackend?> _open(WidgetTester t, {bool online = true, Gps? gps}) async {
  t.view.physicalSize = const Size(390, 844) * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(_seed());
  final prefs = await SharedPreferences.getInstance();
  final backend = online ? FriendsBackend(FakeFirebaseFirestore()) : null;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
        friendsBackendProvider.overrideWithValue(backend),
        if (gps != null) gpsProvider.overrideWithValue(gps),
      ],
      child: const FitTrackerApp(),
    ),
  );
  await _wait(t, 5600);
  return backend;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('without an online account Friends explains it is coming', (t) async {
    await _open(t, online: false);
    await t.tap(find.byTooltip('Friends'));
    await _wait(t);
    expect(find.text('Friends is almost here'), findsOneWidget);
  });

  testWidgets('create a challenge, join one by code, see friends on the leaderboard', (t) async {
    final b = (await _open(t))!;
    // The profile is shared as soon as the app opens.
    expect((await b.profile('demo'))?.name, 'Asha');

    await t.tap(find.byTooltip('Friends'));
    await _wait(t);
    expect(find.text('Challenges'), findsOneWidget);
    expect(find.text('Asha (you)'), findsOneWidget);

    // Create one: squats × 15.
    await t.tap(find.text('Challenge'));
    await _wait(t);
    await t.tap(find.text('Squats'));
    await _wait(t, 300);
    await t.tap(find.byTooltip('More'));
    await t.tap(find.byTooltip('More'));
    await _wait(t, 300);
    expect(find.text('× 12'), findsOneWidget);
    await t.tap(find.text('Create & share'));
    await _wait(t, 1500);
    expect(find.textContaining('You: 12 squats'), findsOneWidget);
    expect(find.textContaining('Waiting for someone to join'), findsOneWidget);

    // Ravi (Master of Winter) has an open challenge; Asha enters his code.
    const ravi = PublicProfile(
      uid: 'ravi',
      name: 'Ravi',
      title: 'Master of Winter 2026',
      titleTier: 2,
      titleSeason: 'winter',
      xp: 5000,
    );
    await b.syncProfile(ravi);
    final c = await b.createChallenge(from: ravi, exercise: Exercise.pushUp, reps: 10, arcLabel: 'Winter Arc 2026');
    await t.tap(find.text('Enter code'));
    await _wait(t);
    await t.enterText(find.byType(TextField), c.code.toLowerCase());
    await t.tap(find.text('Find'));
    await _wait(t, 1500);
    expect(find.text('Ravi challenges you'), findsOneWidget);
    expect(find.text('Master of Winter 2026'), findsOneWidget);
    await t.tap(find.text('Not now'));
    await _wait(t);

    // Accepting then doing it with the camera makes them friends (both done).
    final joined = await b.accept(c, (await b.profile('demo'))!);
    await b.markDone(joined, 'ravi');
    await _wait(t, 1500);
    expect(find.text('Your turn!'), findsOneWidget);
    await b.markDone(joined, 'demo');
    await _wait(t, 1500);
    expect(find.textContaining('friends ✓'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Ravi'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('5000 XP'), findsOneWidget);

    // His profile shows the badge title.
    await t.tap(find.text('Ravi'));
    await _wait(t, 1500);
    expect(find.text('Challenge Ravi'), findsOneWidget);
    expect(find.text('Master of Winter 2026'), findsOneWidget);
  });

  testWidgets('clubs: create one, chat, links are refused', (t) async {
    final b = (await _open(t))!;
    await t.tap(find.byTooltip('Friends'));
    await _wait(t);
    await t.tap(find.text('Clubs'));
    await _wait(t);
    expect(find.text('No clubs here yet. Start one!'), findsOneWidget);

    await t.tap(find.text('Create a club'));
    await _wait(t);
    await t.enterText(find.widgetWithText(TextField, 'Club name'), 'Morning Walkers');
    await t.tap(find.text('Walking').last);
    await t.tap(find.text('Create club'));
    await _wait(t, 1500);

    // In the chat: a note about 24 hours, a link is refused, a normal message goes.
    expect(find.text('Morning Walkers'), findsOneWidget);
    expect(find.text('Messages disappear after 24 hours. Links are not allowed.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Message the club'), 'join fitgang.in');
    await t.tap(find.byTooltip('Send'));
    await _wait(t, 500);
    expect(find.text('Links are not allowed in clubs.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Message the club'), 'Walk at 6 tomorrow?');
    await t.tap(find.byTooltip('Send'));
    await _wait(t, 1000);
    expect(find.text('Walk at 6 tomorrow?'), findsOneWidget);
    final club = (await b.db.collection('clubs').get()).docs.single;
    expect(club['ownerUid'], 'demo');
  });

  testWidgets('club challenge: the admin sets one, runs it with GPS, earns XP and tops the ranking', (t) async {
    final b = (await _open(t, gps: const _FakeGps()))!;
    await t.tap(find.byTooltip('Friends'));
    await _wait(t);
    await t.tap(find.text('Clubs'));
    await _wait(t);
    await t.tap(find.text('Create a club'));
    await _wait(t);
    await t.enterText(find.widgetWithText(TextField, 'Club name'), 'Lake Runners');
    await t.tap(find.text('Create club'));
    await _wait(t, 1500);
    expect(find.text('You are the admin'), findsOneWidget);

    await t.tap(find.text('Challenges'));
    await _wait(t);
    await t.tap(find.text('New challenge'));
    await _wait(t);
    // 1 km: drag the distance slider all the way down, then one step up.
    await t.drag(find.byType(Slider), const Offset(-600, 0));
    await _wait(t, 300);
    expect(find.text('Distance: 0.5 km'), findsOneWidget);
    await t.tap(find.text('Create challenge'));
    await _wait(t, 1500);
    expect(find.text('Run 0.5 km'), findsOneWidget);

    await t.tap(find.text('Run 0.5 km'));
    await _wait(t);
    expect(find.text('No one has finished yet. Be the first!'), findsOneWidget);
    await t.tap(find.text('Start challenge'));
    await _wait(t);
    await t.tap(find.text('Start'));
    await _wait(t, 3000);
    expect(find.text('Finished! 🎉'), findsOneWidget);
    expect(find.text('+55 XP'), findsOneWidget);
    expect(find.text('Saved to the club ranking.'), findsOneWidget);
    await t.tap(find.text('See ranking'));
    await _wait(t);
    expect(find.text('Asha (you)'), findsOneWidget);
    final club = (await b.db.collection('clubs').get()).docs.single.id;
    final ch = (await b.db.collection('clubs/$club/challenges').get()).docs.single.id;
    final r = (await b.db.doc('clubs/$club/challenges/$ch/results/demo').get()).data()!;
    expect(r['distanceM'], greaterThanOrEqualTo(500));
    expect(r['timeMs'], greaterThan(ActivityKind.run.minMillis(500)));
  });

  testWidgets('a scheduled challenge counts down and Start turns on at the start time', (t) async {
    var now = DateTime(2026, 11, 9, 5, 30);
    await withClock(Clock(() => now), () async {
      final b = (await _open(t, gps: const _FakeGps()))!;
      final clubs = ClubsBackend(b.db);
      final club = await clubs.create(
        uid: 'demo',
        myName: 'Asha',
        name: 'Dawn Walkers',
        about: '',
        kind: ClubKind.walking,
      );
      final startsAt = DateTime(2026, 11, 9, 6);
      await clubs.createChallenge(
        club.id,
        uid: 'demo',
        title: 'Sunrise walk',
        kind: ActivityKind.walk,
        distanceM: 2000,
        startsAt: startsAt,
        endsAt: startsAt.add(const Duration(hours: 2)),
      );
      await t.tap(find.byTooltip('Friends'));
      await _wait(t);
      await t.tap(find.text('Clubs'));
      await _wait(t);
      await t.tap(find.text('Dawn Walkers'));
      await _wait(t);
      await t.tap(find.text('Challenges'));
      await _wait(t);
      await t.tap(find.text('Sunrise walk'));
      await _wait(t);

      // 30 minutes before: locked, with a countdown.
      final locked = find.ancestor(of: find.text('Starts in 30 min 00 s'), matching: find.byType(GradientButton));
      expect(t.widget<GradientButton>(locked).onPressed, isNull);
      expect(find.text('The Start button turns on at 9 Nov, 6:00 AM.'), findsOneWidget);

      now = DateTime(2026, 11, 9, 5, 59, 58);
      await _wait(t, 1100);
      expect(find.text('Starts in 0 min 02 s'), findsOneWidget);

      // At 6:00 it turns on by itself.
      now = DateTime(2026, 11, 9, 6, 0, 1);
      await _wait(t, 1100);
      final open = find.ancestor(of: find.text('Start challenge'), matching: find.byType(GradientButton));
      expect(t.widget<GradientButton>(open).onPressed, isNotNull);

      // After the end, it's closed.
      now = DateTime(2026, 11, 9, 8, 0, 1);
      await _wait(t, 1100);
      expect(find.text('Challenge ended'), findsOneWidget);
    });
  });
}

/// A jog north at about 10 km/h, one reading every 10 seconds.
class _FakeGps extends Gps {
  const _FakeGps();

  @override
  Future<String?> ensure() async => null;

  @override
  Future<GpsFix?> current() async => GpsFix(12.97, 77.59, 5, DateTime(2026, 11, 9, 6));

  @override
  Stream<GpsFix> track() async* {
    for (var i = 0; i < 400; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      yield GpsFix(12.97 + i * 0.00025, 77.59, 6, DateTime(2026, 11, 9, 6).add(Duration(seconds: i * 10)));
    }
  }
}
