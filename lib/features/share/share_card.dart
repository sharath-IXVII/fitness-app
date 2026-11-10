import 'dart:ui' as ui;

import '../../core/i18n/i18n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../clubs/report_screen.dart' show saveImageProvider;
import '../snaps/snap_screen.dart' show shareSnapProvider;

/// What a share card says: a big symbol, a headline and a few numbers.
class ShareCardData {
  const ShareCardData({
    required this.symbol,
    required this.headline,
    required this.subtitle,
    this.stats = const [],
    this.caption = '',
    required this.shareText,
  });

  /// An emoji, e.g. "🔥".
  final String symbol;
  final String headline;
  final String subtitle;

  /// (value, label), e.g. ("25 min", "Time").
  final List<(String, String)> stats;

  /// A short line at the bottom.
  final String caption;
  final String shareText;

  factory ShareCardData.streak(int days) => ShareCardData(
    symbol: '🔥',
    headline: '$days-day streak',
    subtitle: 'Every daily goal, $days days in a row.',
    caption: days >= 30 ? 'Habits made, not wished for.' : 'Consistency is the real workout.',
    shareText: 'I\'m on a $days-day streak on FittArc! 🔥 fittarc.in',
  );

  factory ShareCardData.workout({required String name, required int seconds, required int kcal, int streak = 0}) =>
      ShareCardData(
        symbol: '💪',
        headline: 'Workout done',
        subtitle: name,
        stats: [('${(seconds / 60).ceil()} min', 'Time'), ('$kcal', 'kcal'), if (streak > 0) ('$streak', 'Day streak')],
        shareText: 'Just finished "$name" on FittArc 💪 fittarc.in',
      );

  factory ShareCardData.badge({required String title, required String description}) => ShareCardData(
    symbol: '🏅',
    headline: title,
    subtitle: description,
    caption: 'Badge unlocked',
    shareText: 'New badge on FittArc: $title 🏅 fittarc.in',
  );
}

/// Streak lengths worth celebrating.
const streakMilestones = {3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365};

/// The card itself, story-sized (360 × 640, saved at 1080 × 1920).
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  static const size = Size(360, 640);

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.textPrimary, muted = AppColors.textSecondary, accent = AppColors.primary;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surface, AppColors.primarySoft],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('d MMM y').format(DateTime.now()),
                      style: GoogleFonts.inter(fontSize: 11, color: muted),
                    ),
                    const Spacer(),
                    Text('FittArc',
                      style: GoogleFonts.chakraPetch(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: muted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 150,
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 30)],
                  ),
                  child: Text(data.symbol, style: const TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 26),
                Text(
                  data.headline,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.chakraPetch(fontSize: 34, fontWeight: FontWeight.w700, color: ink, height: 1.05),
                ),
                const SizedBox(height: 8),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: muted, height: 1.3),
                ),
                if (data.stats.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      for (final (v, l) in data.stats)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                v,
                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
                              ),
                              Text(l, style: GoogleFonts.inter(fontSize: 11, color: muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const Spacer(),
                if (data.caption.isNotEmpty)
                  Text(
                    data.caption,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a share card with Share and Download.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key, required this.data});

  final ShareCardData data;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _image(Future<void> Function(Uint8List) use, String done) async {
    setState(() => _busy = true);
    try {
      final box = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await box.toImage(pixelRatio: 1080 / ShareCard.size.width);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      await use(data!.buffer.asUint8List());
      if (mounted && done.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      debugPrint('share card: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Share'))),
    body: PageBackground(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: RepaintBoundary(
                    key: _boundary,
                    child: ShareCard(data: widget.data),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: tr('Share'),
                      icon: Icons.ios_share_rounded,
                      onPressed: _busy
                          ? null
                          : () => _image((png) => ref.read(shareSnapProvider)(png, widget.data.shareText), ''),
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
                              (png) =>
                                  ref.read(saveImageProvider)(png, 'fittarc-${DateTime.now().millisecondsSinceEpoch}'),
                              'Saved to your gallery.',
                            ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(tr('Download')),
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
