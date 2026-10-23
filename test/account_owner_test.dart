import 'dart:convert';

import 'package:fitalarm/core/local_data.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/profile/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("a different account signing in doesn't see the last person's data", () async {
    SharedPreferences.setMockInitialValues({
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
      'log.v1.2026-10-22': jsonEncode({'water': 1500}),
      'auth.demo.v1': '{}',
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final local = c.read(localDataProvider);

    await local.claimFor('asha'); // first sign-in on this phone: keeps her data
    expect(c.read(profileProvider)?.name, 'Asha');
    await local.claimFor('asha'); // same person again: still kept
    expect(prefs.getString('log.v1.2026-10-22'), isNotNull);

    await local.claimFor('ravi'); // someone else: wiped
    expect(c.read(profileProvider), isNull);
    expect(prefs.getString('log.v1.2026-10-22'), isNull);
    expect(prefs.getString('auth.demo.v1'), isNotNull);
    expect(prefs.getString(LocalData.ownerKey), 'ravi');
  });
}
