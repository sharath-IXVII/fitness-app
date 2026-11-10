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
      backgroundColor: p.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
                    color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.4),
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
      kicker: 'YOUR SEASON',
      big: '${w.activeDays}',
      unit: w.activeDays == 1 ? 'active day' : 'active days',
      lines: ['${w.period.label} is a wrap.', 'Here is how you moved.'],
    ),
    WrappedCard(
      period: w.period,
      kicker: 'WORKOUTS',
      big: '${w.workouts}',
      unit: w.workouts == 1 ? 'workout' : 'workouts',
      lines: ['${w.perfectDays} perfect ${w.perfectDays == 1 ? 'day' : 'days'} (every goal done)'],
    ),
    WrappedCard(
      period: w.period,
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
      kicker: 'ON YOUR PLATE',
      big: '${w.meals}',
      unit: w.meals == 1 ? 'meal logged' : 'meals logged',
      lines: w.topFoods.isEmpty
          ? ['Log meals next season to see your favourites.']
          : ['Your favourites:', for (final (i, f) in w.topFoods.indexed) '${i + 1}. $f'],
    ),
    WrappedCard(
      period: w.period,
      kicker: 'STREAK',
      big: '${w.bestStreak}',
      unit: 'day best streak',
      lines: [
        if (w.tier != null) 'Badge earned: ${w.period.badgeName(w.tier!)} 🏅' else 'Next season, chase the badge!',
        'See you in the next Arc.',
      ],
    ),
  ];
}

/// One Wrapped story card, in the season's colours (360 × 640).
class WrappedCard extends StatelessWidget {
  const WrappedCard({
    super.key,
    required this.period,
    required this.kicker,
    required this.big,
    required this.unit,
    this.lines = const [],
  });

  static const size = Size(360, 640);

  final ArcPeriod period;
  final String kicker;
  final String big;
  final String unit;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final p = period.season.palette;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.ink, p.inkSoft, p.primaryDeep],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(period.season.icon, color: p.energyLight, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        period.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FittArc',
                      style: GoogleFonts.chakraPetch(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white54),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  kicker,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: p.energyLight,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    big,
                    style: GoogleFonts.chakraPetch(
                      fontSize: 88,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  unit,
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 22),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(l, style: GoogleFonts.inter(fontSize: 15, color: Colors.white.withValues(alpha: 0.88))),
                  ),
                const Spacer(),
              ],
            ),
          ),
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
