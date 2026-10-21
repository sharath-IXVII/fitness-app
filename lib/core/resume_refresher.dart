import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Reminders.onChanged = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await ref.read(sharedPrefsProvider).reload();
    if (!mounted) return;
    ref.invalidate(dailyLogsProvider);
    ref.invalidate(doneTodayProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
