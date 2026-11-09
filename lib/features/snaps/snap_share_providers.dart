import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../friends/friends_providers.dart';
import 'snap_share_backend.dart';

final snapShareBackendProvider = Provider<SnapShareBackend?>((ref) {
  final f = ref.watch(friendsBackendProvider);
  return f == null ? null : SnapShareBackend(f.db);
});

/// Snaps friends sent this user (last 24 hours), minus people they blocked
/// in clubs or friends on this phone.
final snapInboxProvider = StreamProvider<List<SharedSnap>>((ref) {
  final b = ref.watch(snapShareBackendProvider), uid = ref.watch(friendsUidProvider);
  if (b == null || uid == null) return Stream.value(const []);
  return b.inbox(uid);
});
