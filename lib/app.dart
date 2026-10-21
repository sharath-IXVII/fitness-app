import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

class FitAlarmApp extends ConsumerWidget {
  const FitAlarmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
