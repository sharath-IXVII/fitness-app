import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../features/report/report_providers.dart';
import '../features/streaks/daily_log_providers.dart';

/// What the home screen widget shows.
typedef WidgetNumbers = ({String streak, String score, String steps, String water});

WidgetNumbers widgetNumbers({required int streak, required int score, required int steps, required int waterMl}) => (
  streak: '$streak',
  score: '$score',
  steps: '👟 ${NumberFormat.decimalPattern('en_IN').format(steps)}',
  water: '💧 ${(waterMl / 1000).toStringAsFixed(1)} L',
);

/// Sends today's numbers to the Android home screen widget whenever they
/// change. Nothing happens on other platforms.
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  WidgetNumbers? last;
  Future<void> push() async {
    final log = ref.read(todayLogProvider);
    final n = widgetNumbers(
      streak: ref.read(streakProvider).current,
      score: ref.read(dailyReportProvider)?.score ?? 0,
      steps: log.steps,
      waterMl: log.waterMl,
    );
    if (n == last) return;
    last = n;
    try {
      await HomeWidget.saveWidgetData('streak', n.streak);
      await HomeWidget.saveWidgetData('score', n.score);
      await HomeWidget.saveWidgetData('steps', n.steps);
      await HomeWidget.saveWidgetData('water', n.water);
      await HomeWidget.updateWidget(androidName: 'FittArcWidget');
    } catch (e) {
      debugPrint('home widget: $e');
    }
  }

  ref.listen(todayLogProvider, (_, _) => push());
  ref.listen(streakProvider, (_, _) => push());
  push();
});
