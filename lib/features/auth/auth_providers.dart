import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud_backup.dart';
import '../../core/local_data.dart';
import 'auth_service.dart';
import 'domain/app_user.dart';

/// Overridden in `main()` with the Firebase or demo implementation.
final authServiceProvider = Provider<AuthService>((ref) => throw UnimplementedError('authServiceProvider'));

class AuthNotifier extends Notifier<AppUser?> {
  StreamSubscription<AppUser?>? _sub;

  @override
  AppUser? build() {
    final service = ref.watch(authServiceProvider);
    _sub = service.changes.listen((u) => state = u);
    ref.onDispose(() => _sub?.cancel());
    return service.currentUser;
  }

  /// Applies a sign-in result immediately rather than waiting for the stream.
  /// If the phone holds another account's data, it's cleared first.
  Future<void> signedIn(AppUser user) async {
    try {
      await ref.read(localDataProvider).claimFor(user.uid);
      // Bring back this account's progress (levels, badges, streaks…) before
      // the app decides whether the user still needs to set up a profile.
      await ref.read(cloudBackupProvider).restore(user.uid);
    } finally {
      // Signing in must finish even if tidying up the phone's data fails.
      state = user;
    }
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    state = null;
  }

  Future<void> deleteAccount() async {
    await ref.read(authServiceProvider).deleteAccount();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
