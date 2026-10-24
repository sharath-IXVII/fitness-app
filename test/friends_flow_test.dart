import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
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

Future<FriendsBackend?> _open(WidgetTester t, {bool online = true}) async {
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
}
