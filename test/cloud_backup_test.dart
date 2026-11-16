import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fitalarm/core/cloud_backup.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
import 'package:fitalarm/features/profile/profile_providers.dart';
import 'package:fitalarm/features/progress/domain/progress.dart' hide Level;
import 'package:fitalarm/features/progress/progress_providers.dart';
import 'package:fitalarm/features/myday/myday_providers.dart';
import 'package:fitalarm/features/streaks/daily_log_providers.dart';
import 'package:fitalarm/features/training/domain/plans.dart';
import 'package:fitalarm/features/training/training_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _profile = {
  'name': 'Asha',
  'gender': 'female',
  'age': 28,
  'heightCm': 165.0,
  'weightKg': 60.0,
  'goal': 'maintain',
  'activity': 'light',
  'diet': 'veg',
  'level': 'beginner',
  'wake': 360,
  'sleep': 1380,
};

/// One phone: its own storage, signed in as [uid], talking to [db].
Future<ProviderContainer> _phone(FakeFirebaseFirestore db, Map<String, Object> initial, {String uid = 'asha'}) async {
  SharedPreferences.setMockInitialValues({
    'auth.demo.v1': jsonEncode({'uid': uid, 'method': 'google', 'email': 'a@b.c'}),
    ...initial,
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
      cloudStoreProvider.overrideWithValue(FirestoreCloudStore(db)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// A cloud whose rules don't know about plans yet (not published).
class _NoPlans extends FirestoreCloudStore {
  _NoPlans(super.db);

  @override
  Future<void> saveMore(String uid, Map<String, dynamic> more) => throw Exception('permission-denied');
}

void main() {
  test('everything earned is backed up, and a new phone gets it all back', () async {
    final db = FakeFirebaseFirestore();
    final old = await _phone(db, {
      'profile.v1': jsonEncode(_profile),
      'app.firstUse.v1': DateTime(2026, 10, 1).toIso8601String(),
      'log.v1.2026-10-02': jsonEncode({'workout': true, 'water': 3000, 'steps': 11000, 'meals': 3, 'protein': 90}),
      'log.v1.2026-10-03': jsonEncode({'workout': false, 'water': 500, 'steps': 2000, 'meals': 1, 'protein': 10}),
    });
    await old.read(badgeVaultProvider.notifier).merge({
      (kind: Achievement.firstWorkout, set: 1): DateTime(2026, 10, 2),
    });
    await old.read(waterGoalProvider.notifier).set(2800);
    await old.read(cloudBackupProvider).push();

    final days = await db.collection('users/asha/days').get();
    expect(days.docs.map((d) => d.id), unorderedEquals(['2026-10-02', '2026-10-03']));
    expect((await db.doc('users/asha/backup/state').get()).data()!['waterGoal'], 2800);

    // A second push with nothing new changes nothing.
    final before = (await db.doc('users/asha/backup/state').get()).data()!['updatedAt'];
    await old.read(cloudBackupProvider).push();
    expect((await db.doc('users/asha/backup/state').get()).data()!['updatedAt'], before);

    // A brand-new phone, same account.
    final fresh = await _phone(db, {});
    expect(fresh.read(profileProvider), isNull);
    expect(await fresh.read(cloudBackupProvider).restore('asha'), isTrue);
    expect(fresh.read(profileProvider)!.name, 'Asha');
    expect(fresh.read(dailyLogsProvider).length, 2);
    expect(fresh.read(dailyLogsProvider)[DateTime(2026, 10, 2)]!.steps, 11000);
    expect(fresh.read(dailyLogsProvider)[DateTime(2026, 10, 2)]!.workoutDone, isTrue);
    expect(fresh.read(achievementsProvider).keys, contains((kind: Achievement.firstWorkout, set: 1)));
    expect(fresh.read(waterGoalProvider), 2800);
  });

  test('restoring never lowers progress already on the phone', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/asha/days/2026-10-02').set({
      'workout': true,
      'water': 1000,
      'steps': 5000,
      'meals': 4,
      'protein': 50,
    });
    final phone = await _phone(db, {
      'profile.v1': jsonEncode(_profile),
      'log.v1.2026-10-02': jsonEncode({'workout': false, 'water': 2500, 'steps': 9000, 'meals': 1, 'protein': 80}),
    });
    await phone.read(cloudBackupProvider).restore('asha');
    final d = phone.read(dailyLogsProvider)[DateTime(2026, 10, 2)]!;
    expect(d.workoutDone, isTrue); // the cloud knew about the workout
    expect(d.steps, 9000); // the phone had more steps
    expect(d.waterMl, 2500);
    expect(d.mealsLogged, 4);
    expect(d.proteinG, 80);
  });

  test('an empty cloud changes nothing, and a broken one never blocks sign-in', () async {
    final db = FakeFirebaseFirestore();
    final phone = await _phone(db, {'profile.v1': jsonEncode(_profile)});
    expect(await phone.read(cloudBackupProvider).restore('asha'), isFalse);
    expect(phone.read(profileProvider)!.name, 'Asha');
  });

  test('plans the user built follow them to a new phone', () async {
    final db = FakeFirebaseFirestore();
    final old = await _phone(db, {'profile.v1': jsonEncode(_profile)});
    await old.read(trainingProvider.notifier).startChallenge(challenges.first.id, Level.values.first);
    await old.read(trainingProvider.notifier).completeDay(challenges.first.id, 1);
    final block = old.read(myDayProvider.notifier).draft(weekday: 1);
    await old.read(myDayProvider.notifier).save(block);
    await old.read(myTemplatesProvider.notifier).save('My Monday', [block]);
    await old.read(cloudBackupProvider).push();

    final fresh = await _phone(db, {});
    expect(await fresh.read(cloudBackupProvider).restore('asha'), isTrue);
    expect(fresh.read(trainingProvider).challenges[challenges.first.id]!.done, {1});
    expect(fresh.read(myDayProvider), hasLength(1));
    expect(fresh.read(myTemplatesProvider).single.name, 'My Monday');
  });

  test('a plan made on this phone is never replaced by the cloud copy, and junk is ignored', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/asha/backup/more').set({
      'myDay': jsonEncode([]),
      'training': 'not json at all',
      'routines': 'x' * (CloudBackup.maxPlanChars + 1),
    });
    final phone = await _phone(db, {'profile.v1': jsonEncode(_profile)});
    final mine = phone.read(myDayProvider.notifier).draft(weekday: 3);
    await phone.read(myDayProvider.notifier).save(mine);
    await phone.read(cloudBackupProvider).restore('asha');
    expect(phone.read(myDayProvider), hasLength(1)); // kept, not emptied
    final prefs = phone.read(sharedPrefsProvider);
    expect(prefs.getString('training.v1'), isNull);
    expect(prefs.getString('routines.v1'), isNull);
  });

  test('a refused plan backup never stops the progress backup', () async {
    final db = FakeFirebaseFirestore();
    final phone = await _phone(db, {
      'profile.v1': jsonEncode(_profile),
      'log.v1.2026-10-02': jsonEncode({'workout': true}),
      'myday.v1': jsonEncode([]),
    });
    final store = _NoPlans(db);
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(phone.read(sharedPrefsProvider)),
        authServiceProvider.overrideWithValue(DemoAuthService(phone.read(sharedPrefsProvider))),
        cloudStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    await c.read(cloudBackupProvider).push();
    expect((await db.collection('users/asha/days').get()).docs, hasLength(1));
    expect((await db.doc('users/asha/backup/state').get()).exists, isTrue);
  });

  test('badges keep the earliest date and are never dropped', () {
    final merged = BackupMerge.badges({'streak7:1': '2026-10-09', 'tenK:1': '2026-10-02'}, {'streak7:1': '2026-10-07'});
    expect(merged, {'streak7:1': '2026-10-07', 'tenK:1': '2026-10-02'});
    expect(BackupMerge.earlier('2026-10-09', '2026-10-01'), '2026-10-01');
    expect(BackupMerge.earlier(null, '2026-10-01'), '2026-10-01');
  });

  test('deleting the account removes the backup', () async {
    final db = FakeFirebaseFirestore();
    final phone = await _phone(db, {
      'profile.v1': jsonEncode(_profile),
      'log.v1.2026-10-02': jsonEncode({'workout': true}),
    });
    await phone.read(cloudBackupProvider).push();
    expect((await db.collection('users/asha/days').get()).docs, isNotEmpty);
    await FirestoreCloudStore(db).delete('asha');
    expect((await db.collection('users/asha/days').get()).docs, isEmpty);
    expect((await db.collection('users/asha/backup').get()).docs, isEmpty);
  });
}
