import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../clubs/report_screen.dart' show saveImageProvider;
import '../snaps/snap_screen.dart' show shareSnapProvider;
import 'domain/daily_report.dart';
import 'report_providers.dart';

/// Today's report: score, goals, food, snaps and club runs, to share or save.
class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _image(Future<void> Function(Uint8List) use, String done) async {
    setState(() => _busy = true);
    try {
      final box = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await box.toImage(pixelRatio: 1080 / DailyReportCard.size.width);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      await use(data!.buffer.asUint8List());
      if (mounted && done.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      debugPrint('daily report: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(dailyReportProvider);
    final settings = ref.watch(reportSettingsProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Today's report")),
      body: PageBackground(
        child: r == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: FittedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: RepaintBoundary(
                            key: _boundary,
                            child: DailyReportCard(report: r),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GradientButton(
                                  label: 'Share',
                                  icon: Icons.ios_share_rounded,
                                  onPressed: _busy
                                      ? null
                                      : () => _image(
                                          (png) => ref.read(shareSnapProvider)(
                                            png,
                                            'My day on FittArc: ${r.score}/100. fittarc.in',
                                          ),
                                          '',
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(60),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _image(
                                          (png) => ref.read(saveImageProvider)(
                                            png,
                                            'fittarc-day-${DateFormat('yyyyMMdd').format(r.day)}',
                                          ),
                                          'Saved to your gallery.',
                                        ),
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text('Download'),
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: settings.enabled,
                            onChanged: (v) => ref.read(reportSettingsProvider.notifier).set(enabled: v),
                            title: Text('Evening reminder', style: text.titleSmall),
                            subtitle: Text(
                              'Every day at ${DateFormat.jm().format(DateTime(2026, 1, 1, settings.minute ~/ 60, settings.minute % 60))}. '
                              'Tap to change the time.',
                              style: text.bodySmall,
                            ),
                            secondary: IconButton(
                              tooltip: 'Change time',
                              icon: const Icon(Icons.schedule_rounded),
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: settings.minute ~/ 60, minute: settings.minute % 60),
                                );
                                if (t != null) {
                                  await ref.read(reportSettingsProvider.notifier).set(minute: t.hour * 60 + t.minute);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The report as a story-sized card (360 × 640, saved at 1080 × 1920).
class DailyReportCard extends StatelessWidget {
  const DailyReportCard({super.key, required this.report});

  static const size = Size(360, 640);

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final ink = AppColors.textPrimary, muted = AppColors.textSecondary, accent = AppColors.primary;
    TextStyle sport(double s) =>
        GoogleFonts.chakraPetch(fontSize: s, fontWeight: FontWeight.w700, color: ink, height: 1);
    TextStyle body(double s, [Color? c, FontWeight w = FontWeight.w500]) =>
        GoogleFonts.inter(fontSize: s, fontWeight: w, color: c ?? ink, height: 1.25);
    String n(num v) => NumberFormat.decimalPattern('en_IN').format(v.round());
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surface, AppColors.background],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('My day', style: body(15, ink, FontWeight.w700)),
                    const Spacer(),
                    Text('FittArc', style: sport(14).copyWith(color: muted.withValues(alpha: 0.7))),
                  ],
                ),
                Text(DateFormat('EEEE, d MMMM').format(r.day), style: body(10.5, muted)),
                const SizedBox(height: 18),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: r.score / 100,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.surfaceHigh,
                          color: accent,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${r.score}', style: sport(48)),
                              Text('out of 100', style: body(10, muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(r.verdict, style: body(12.5, ink, FontWeight.w600), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
                _row(
                  Icons.fitness_center_rounded,
                  'Workout',
                  r.workoutDone ? 'Done ✓' : 'Not yet',
                  r.workoutDone ? 1 : 0,
                  body,
                  accent,
                ),
                for (final l in r.lines)
                  _row(
                    switch (l.label) {
                      'Steps' => Icons.directions_walk_rounded,
                      'Water' => Icons.water_drop_rounded,
                      'Meals logged' => Icons.restaurant_rounded,
                      _ => Icons.egg_alt_rounded,
                    },
                    l.label,
                    '${n(l.done)}${l.unit.isEmpty ? '' : ' ${l.unit}'} / ${n(l.goal)}${l.unit.isEmpty ? '' : ' ${l.unit}'}',
                    l.part,
                    body,
                    accent,
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _chip('${n(r.kcalEaten)} kcal', 'eaten of ${n(r.kcalTarget)}', body),
                    _chip('${r.snaps}', r.snaps == 1 ? 'food snap' : 'food snaps', body),
                    _chip('🔥 ${r.streak}', 'day streak', body),
                    if (r.clubKm > 0) _chip(r.clubKm.toStringAsFixed(1), 'club km', body),
                  ],
                ),
                const Spacer(),
                if (r.tip case final tip?) Text(tip, style: body(11, muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(
    IconData icon,
    String label,
    String value,
    double part,
    TextStyle Function(double, [Color?, FontWeight]) body,
    Color accent,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: body(11.5, null, FontWeight.w600))),
            Text(value, style: body(11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: part,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
            color: part >= 1 ? accent : accent.withValues(alpha: 0.55),
          ),
        ),
      ],
    ),
  );

  static Widget _chip(String value, String label, TextStyle Function(double, [Color?, FontWeight]) body) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: body(12, null, FontWeight.w700), maxLines: 1),
          Text(label, style: body(8.5, AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

/// "Today's report: 72/100" on the Today page.
class TodayReportTile extends ConsumerWidget {
  const TodayReportTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(dailyReportProvider);
    if (r == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(Routes.dailyReport),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: r.score / 100,
                      strokeWidth: 5,
                      backgroundColor: AppColors.surfaceHigh,
                      color: AppColors.primary,
                    ),
                    Center(child: Text('${r.score}', style: text.titleSmall)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's report", style: text.titleMedium),
                    Text('Your score, goals and food for today. Share it!', style: text.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
