import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/resume_refresher.dart';
import 'core/router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/alarm/alarm_ring_listener.dart';
import 'features/arcs/arc_providers.dart';

class FitTrackerApp extends ConsumerWidget {
  const FitTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The look follows the seasonal arc. Colours are read straight from
    // AppColors, so when the season changes every widget is rebuilt.
    final season = ref.watch(themeSeasonProvider);
    if (!identical(AppColors.palette, season.palette)) {
      AppColors.use(season.palette);
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll(context));
    }
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      // Times are always shown with AM and PM, whatever the phone's clock setting.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: ResumeRefresher(child: AlarmRingListener(child: child!)),
      ),
    );
  }

  static void _rebuildAll(BuildContext context) {
    if (!context.mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }
}
