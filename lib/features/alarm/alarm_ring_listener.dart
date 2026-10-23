import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router.dart';
import '../../core/storage.dart';
import 'alarm_providers.dart';
import 'alarm_scheduler.dart';
import 'strict_mode.dart';

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
  ChangeNotifier? _delegate;

  @override
  void initState() {
    super.initState();
    _sub = AlarmScheduler.ringing.listen(_onRinging);
    // An alarm that starts while the user is mid-workout is held back; show
    // it as soon as they leave that screen.
    _delegate = ref.read(routerProvider).routerDelegate..addListener(_onRouteChanged);
    // Re-arm everything on launch (e.g. after a reboot or an app update), and
    // ring again if a strict alarm was interrupted before it was finished.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(alarmsProvider.notifier).resync();
      final pending = StrictMode.pending(ref.read(sharedPrefsProvider));
      if (pending != null && AlarmScheduler.ringingNow.isEmpty) await AlarmScheduler.ringSoon(pending);
    });
  }

  static const _busy = {Routes.splash, Routes.ring, Routes.workout, Routes.challenge};

  void _onRinging(List<RingInfo> ringing) {
    if (ringing.isEmpty) return;
    final router = ref.read(routerProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    // The splash routes to the ring screen itself once it's done.
    if (_busy.contains(path)) return;
    router.go(Routes.ring, extra: ringing.first);
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final router = ref.read(routerProvider);
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (_busy.contains(path) || path == Routes.workoutDone) return;
    final ringing = AlarmScheduler.ringingNow;
    if (ringing.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) router.go(Routes.ring, extra: ringing.first);
      });
    }
  }

  @override
  void dispose() {
    _delegate?.removeListener(_onRouteChanged);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
