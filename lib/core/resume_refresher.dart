import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/arcs/arc_providers.dart';
import '../features/diet/diet_providers.dart';
import '../features/myday/myday_providers.dart';
import '../features/streaks/daily_log_providers.dart';
import 'reminders.dart';
import 'storage.dart';

/// Notification actions ("Done", "+250 ml") can write to storage from a
/// background isolate. When the app returns to the foreground, reload
/// storage and rebuild the providers that read it.
class ResumeRefresher extends ConsumerStatefulWidget {
  const ResumeRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ResumeRefresher> createState() => _ResumeRefresherState();
}

class _ResumeRefresherState extends ConsumerState<ResumeRefresher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Reminders.onChanged = _refresh;
    _armMidnight();
  }

  Timer? _midnight;

  /// Refreshes just after midnight even if the app stays open, so a new day
  /// (and on the 1st of Jan, Apr, Jul and Oct, a new arc) starts on time.
  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      _refresh();
      _armMidnight();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Reminders.onChanged = null;
    _midnight?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _armMidnight(); // timers don't run while the phone sleeps
    }
  }

  Future<void> _refresh() async {
    await ref.read(sharedPrefsProvider).reload();
    if (!mounted) return;
    ref.invalidate(dailyLogsProvider);
    ref.invalidate(doneTodayProvider);
    ref.invalidate(mealLogProvider);
    // A new day may start a new arc, and with it a new look.
    ref.read(todayProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
