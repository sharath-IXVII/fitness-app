import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/i18n/i18n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../snaps/snap_screen.dart' show shareSnapProvider;
import 'clubs_providers.dart';
import 'domain/club_challenge.dart';
import 'domain/run_report.dart';
import 'widgets/route_map.dart';

/// Saves a PNG to the phone's gallery. Overridden in tests.
final saveImageProvider = Provider<Future<void> Function(Uint8List png, String name)>(
  (ref) =>
      (png, name) => Gal.putImageBytes(png, name: name),
);

/// A member's performance report after a challenge: distance, time, pace,
/// speed, calories, km splits, rank and the route. Kept for 5 hours.
class RunReportScreen extends ConsumerStatefulWidget {
  const RunReportScreen({super.key, required this.id, this.report});

  final String id;

  /// Shown as it is (a saved activity), instead of the 5-hour club report.
  final RunReport? report;

  @override
  ConsumerState<RunReportScreen> createState() => _RunReportScreenState();
}

class _RunReportScreenState extends ConsumerState<RunReportScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(runReportsProvider.notifier).prune());
  }

  Future<Uint8List?> _png() async {
    final box = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return null;
    final image = await box.toImage(pixelRatio: 1080 / RunReportCard.size.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<void> _do(Future<void> Function(Uint8List png) action, String done, String failed) async {
    setState(() => _busy = true);
    try {
      final png = await _png();
      if (png != null) await action(png);
      if (mounted && done.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      debugPrint('report: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kept = widget.report == null;
    final r = widget.report ?? ref.watch(runReportProvider(widget.id));
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.report == null ? 'My report' : widget.report!.title)),
      body: PageBackground(
        child: r == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(tr('This report is gone. Reports are kept for 5 hours after a challenge.'),
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
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
                            child: RunReportCard(report: r),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                        children: [
                          if (hasMaps && r.route.length > 1)
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(title: Text(r.title)),
                                    body: RouteMap(route: r.route),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.map_rounded),
                              label: Text(tr('See the route on the map')),
                            ),
                          if (kept)
                          Text(
                            'Kept until ${DateFormat('h:mm a').format(r.expiresAt)}. Download it to keep it.',
                            style: text.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GradientButton(
                                  label: tr('Download'),
                                  icon: Icons.download_rounded,
                                  onPressed: _busy
                                      ? null
                                      : () => _do(
                                          (png) => ref.read(saveImageProvider)(png, 'fittarc-${r.id}'),
                                          'Saved to your gallery.',
                                          "Couldn't save. Allow FittArc to add photos, then try again.",
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
                                      : () => _do(
                                          (png) => ref.read(shareSnapProvider)(
                                            png,
                                            '${r.title}: ${formatKm(r.distanceM)} in ${formatDuration(r.timeMs)}. '
                                            'Tracked with FittArc, fittarc.in',
                                          ),
                                          '',
                                          "Couldn't share. Try again.",
                                        ),
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: Text(tr('Share')),
                                ),
                              ),
                            ],
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
class RunReportCard extends StatelessWidget {
  const RunReportCard({super.key, required this.report});

  static const size = Size(360, 640);

  final RunReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final ink = AppColors.textPrimary, muted = AppColors.textSecondary, accent = AppColors.primary;
    TextStyle sport(double s) =>
        GoogleFonts.chakraPetch(fontSize: s, fontWeight: FontWeight.w700, color: ink, height: 1);
    TextStyle body(double s, [Color? c, FontWeight w = FontWeight.w500]) =>
        GoogleFonts.inter(fontSize: s, fontWeight: w, color: c ?? ink, height: 1.25);
    final laps = r.lapMs;
    final fastest = laps.isEmpty ? 0 : laps.reduce(math.min);
    final slowest = laps.isEmpty ? 1 : laps.reduce(math.max);
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.kind.icon, color: accent, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.title,
                        style: body(14, ink, FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('FittArc', style: sport(14).copyWith(color: muted.withValues(alpha: 0.7))),
                  ],
                ),
                Text(
                  '${r.clubName.isEmpty ? '' : '${r.clubName} · '}${DateFormat('d MMM y, h:mm a').format(r.finishedAt)}',
                  style: body(10, muted),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text((r.distanceM / 1000).toStringAsFixed(2), style: sport(46)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(tr('km'), style: body(16, muted)),
                    ),
                    const Spacer(),
                    if (r.rank != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '#${r.rank}${r.of == null ? '' : ' of ${r.of}'}',
                          style: body(13, Colors.white, FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('Time', formatDuration(r.timeMs), body),
                    _stat(
                      r.kind == ActivityKind.cycle ? 'Speed' : 'Pace',
                      r.kind == ActivityKind.cycle
                          ? '${r.avgKmh.toStringAsFixed(1)} km/h'
                          : formatPace(r.timeMs, r.distanceM).replaceAll(' /km', ''),
                      body,
                    ),
                    _stat('Avg speed', '${r.avgKmh.toStringAsFixed(1)} km/h', body),
                    _stat('kcal', '${r.kcal}', body),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.all(14),
                    child: r.route.length < 2
                        ? Center(child: Text(tr('Route'), style: body(11, muted)))
                        : RouteSketch(route: r.route, color: accent),
                  ),
                ),
                const SizedBox(height: 12),
                if (laps.isNotEmpty) ...[
                  Text(tr('Splits per km'), style: body(11, muted, FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final (i, ms) in laps.indexed.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 26, child: Text('${i + 1}', style: body(10, muted))),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: slowest == 0 ? 1 : (0.35 + 0.65 * ms / slowest).clamp(0.0, 1.0),
                                child: Container(
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: ms == fastest ? accent : accent.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(formatDuration(ms), style: body(10), textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                  if (laps.length > 6) Text('+ ${laps.length - 6} more km', style: body(9, muted)),
                ],
                if (r.xp > 0) ...[
                  const SizedBox(height: 8),
                  Text('+${r.xp} XP earned', style: body(12, accent, FontWeight.w700)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _stat(String label, String value, TextStyle Function(double, [Color?, FontWeight]) body) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: body(14, null, FontWeight.w700), maxLines: 1),
        Text(label, style: body(9.5, AppColors.textSecondary)),
      ],
    ),
  );
}
