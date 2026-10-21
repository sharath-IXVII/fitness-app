import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';

/// Opens the ring screen whenever an alarm starts ringing, unless the user
/// is already on it or mid-workout (the workout handles its own watchdog).
class AlarmRingListener extends ConsumerStatefulWidget {
  const AlarmRingListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlarmRingListener> createState() => _AlarmRingListenerState();
}

class _AlarmRingListenerState extends ConsumerState<AlarmRingListener> {
  StreamSubscription<List<RingInfo>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AlarmScheduler.ringing.listen(_onRinging);
    // Re-arm everything on launch (e.g. after a reboot or an app update).
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(alarmsProvider.notifier).resync());
  }

  void _onRinging(List<RingInfo> ringing) {
    if (ringing.isEmpty) return;
    final router = ref.read(routerProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    // The splash routes to the ring screen itself once it's done.
    if (path == Routes.splash || path == Routes.ring || path == Routes.workout) return;
    router.go(Routes.ring, extra: ringing.first);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
