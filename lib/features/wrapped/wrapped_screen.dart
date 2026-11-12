import 'dart:ui' as ui;

import '../../core/i18n/i18n.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/widgets/page_background.dart' show ArcWeather;
import '../../core/widgets/gradient_button.dart';
import '../arcs/domain/arc.dart';
import '../clubs/report_screen.dart' show saveImageProvider;
import '../snaps/snap_screen.dart' show shareSnapProvider;
import '../../core/share_to.dart';
import 'domain/arc_wrapped.dart';
import 'wrapped_providers.dart';

/// The Arc's story: swipe through the season in a few cards, share any.
class ArcWrappedScreen extends ConsumerStatefulWidget {
  const ArcWrappedScreen({super.key, required this.period});

  final ArcPeriod period;

  @override
  ConsumerState<ArcWrappedScreen> createState() => _ArcWrappedScreenState();
}

class _ArcWrappedScreenState extends ConsumerState<ArcWrappedScreen> {
  final _pages = PageController();
  final _keys = List.generate(5, (_) => GlobalKey());
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _image(Future<void> Function(Uint8List) use, String done) async {
    setState(() => _busy = true);
    try {
      final box = _keys[_page].currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await box.toImage(pixelRatio: 1080 / WrappedCard.size.width);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      await use(data!.buffer.asUint8List());
      if (mounted && done.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      debugPrint('wrapped: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(arcWrappedProvider(widget.period));
    final cards = wrappedCards(w);
    final p = widget.period.season.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        title: Text('${widget.period.label} Wrapped'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final (i, c) in cards.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: FittedBox(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: RepaintBoundary(key: _keys[i], child: c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: i == _page ? 0.9 : 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShareRow(
                    apps: const [ShareApp.whatsapp, ShareApp.instagram],
                    busy: _busy,
                    onShare: (app) => _image(
                      (png) => ref.read(shareToAppProvider)(png, 'My ${w.period.label} on FittArc ✨ fittarc.in', app),
                      '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: tr('Share this'),
                          icon: Icons.ios_share_rounded,
                          onPressed: _busy
                              ? null
                              : () => _image(
                                  (png) =>
                                      ref.read(shareSnapProvider)(png, 'My ${w.period.label} on FittArc ✨ fittarc.in'),
                                  '',
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: tr('Download'),
                        onPressed: _busy
                            ? null
                            : () => _image(
                                (png) => ref.read(saveImageProvider)(png, 'fittarc-wrapped-${w.period.label}-$_page'),
                                'Saved to your gallery.',
                              ),
                        icon: const Icon(Icons.download_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The story cards for [w].
List<Widget> wrappedCards(ArcWrapped w) {
  final n = NumberFormat.decimalPattern('en_IN');
  return [
    WrappedCard(
      period: w.period,
      icon: Icons.calendar_month_rounded,
      progress: w.period.totalDays == 0 ? null : (w.activeDays / w.period.totalDays).clamp(0.0, 1.0),
      kicker: 'YOUR SEASON',
      big: '${w.activeDays}',
      unit: w.activeDays == 1 ? 'active day' : 'active days',
      lines: [
        DateTime.now().isBefore(w.period.end) ? '${w.period.label} so far.' : '${w.period.label} is a wrap.',
        'Here is how you moved.',
      ],
    ),
    WrappedCard(
      period: w.period,
      icon: Icons.fitness_center_rounded,
      kicker: 'WORKOUTS',
      big: '${w.workouts}',
      unit: w.workouts == 1 ? 'workout' : 'workouts',
      lines: ['${w.perfectDays} perfect ${w.perfectDays == 1 ? 'day' : 'days'} (every goal done)'],
    ),
    WrappedCard(
      period: w.period,
      icon: Icons.directions_walk_rounded,
      kicker: 'ON YOUR FEET',
      big: n.format(w.steps),
      unit: 'steps',
      lines: [
        'About ${w.km.toStringAsFixed(0)} km walked',
        if (w.bestDay case (final d, final s)) 'Best day: ${DateFormat('d MMM').format(d)}, ${n.format(s)} steps',
        '${(w.waterMl / 1000).toStringAsFixed(0)} litres of water',
      ],
    ),
    WrappedCard(
      period: w.period,
      icon: Icons.restaurant_rounded,
      kicker: 'ON YOUR PLATE',
      big: '${w.meals}',
      unit: w.meals == 1 ? 'meal logged' : 'meals logged',
      lines: w.topFoods.isEmpty
          ? ['Log meals next season to see your favourites.']
          : ['Your favourites:', for (final (i, f) in w.topFoods.indexed) '${i + 1}. $f'],
    ),
    WrappedCard(
      period: w.period,
      icon: Icons.local_fire_department_rounded,
      kicker: 'STREAK',
      big: '${w.bestStreak}',
      unit: 'day best streak',
      lines: [
        if (w.tier != null) 'Badge earned: ${w.period.badgeName(w.tier!)}' else 'Next season, chase the badge!',
        'See you in the next Arc.',
      ],
    ),
  ];
}

/// One Wrapped story card in the arc's own look (360 × 640): its colours and
/// falling weather, a big icon, the number, and the details in a white card.
class WrappedCard extends StatelessWidget {
  const WrappedCard({
    super.key,
    required this.period,
    required this.kicker,
    required this.big,
    required this.unit,
    this.lines = const [],
    this.icon = Icons.bolt_rounded,
    this.progress,
  });

  static const size = Size(360, 640);

  final ArcPeriod period;
  final String kicker;
  final String big;
  final String unit;
  final List<String> lines;
  final IconData icon;

  /// Shown as a ring around the icon (0–1), e.g. active days of the arc.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = period.season.palette;
    TextStyle inter(double s, Color c, [FontWeight w = FontWeight.w500]) =>
        GoogleFonts.inter(fontSize: s, fontWeight: w, color: c, height: 1.3);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.background)),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [p.primarySoft, p.primarySoft.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: ArcWeather(effect: period.season.effect, count: 24)),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(period.season.icon, color: p.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          period.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: inter(10.5, p.primary, FontWeight.w700).copyWith(letterSpacing: 1.4),
                        ),
                      ),
                      Text(
                        'FittArc',
                        style: GoogleFonts.chakraPetch(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // The big icon, with a progress ring when there is one.
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (progress != null)
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            color: p.primary,
                            backgroundColor: p.primary.withValues(alpha: 0.15),
                          ),
                        Padding(
                          padding: EdgeInsets.all(progress != null ? 14 : 4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: p.primary.withValues(alpha: 0.18), blurRadius: 22)],
                            ),
                            child: Icon(icon, color: p.primary, size: 40),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(kicker, style: inter(11.5, p.textSecondary, FontWeight.w700).copyWith(letterSpacing: 2)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      big,
                      style: GoogleFonts.chakraPetch(
                        fontSize: 80,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(unit, style: inter(18, p.textPrimary, FontWeight.w600)),
                  const SizedBox(height: 18),
                  if (lines.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final l in lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6, right: 10),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                                  ),
                                  Expanded(child: Text(l, style: inter(13.5, p.textPrimary))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text('fittarc.in', style: inter(10, p.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Positioned.fill(child: ArcWeather(effect: period.season.effect, foreground: true, count: 7)),
          ],
        ),
      ),
    );
  }
}

/// "Your Winter Arc Wrapped is ready" on the Today page, for two weeks
/// after an Arc ends.
class WrappedReadyTile extends ConsumerWidget {
  const WrappedReadyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(freshWrappedProvider);
    if (period == null) return const SizedBox.shrink();
    final p = period.season.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        color: p.ink,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push(Routes.wrapped, extra: period),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(period.season.icon, color: p.energyLight, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your ${period.label} Wrapped',
                        style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        tr('Your season in 5 cards. Share your favourite!'),
                        style: text.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
