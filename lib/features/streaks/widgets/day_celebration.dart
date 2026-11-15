import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../arcs/domain/arc.dart';

/// What a day's progress has just earned.
enum DayWin { unlocked, perfect }

/// The words for a win, in the season's own picture (ice, bloom, sun, storm).
(String, String) dayWinText(DayWin win, Season season) => switch (win) {
  DayWin.perfect => ('Perfect day!', 'All 5 goals done. Today shines brightest.'),
  DayWin.unlocked => (
    switch (season) {
      Season.winter => 'Ice broken!',
      Season.spring => 'It bloomed!',
      Season.summer => 'The sun is out!',
      Season.monsoon => 'Storm broken!',
    },
    'Today counts for your streak.',
  ),
};

/// A short cheer over whatever screen is open: it rises in, holds for a
/// moment and leaves by itself. It never takes a tap away from the page.
void showDayCelebration(BuildContext context, DayWin win, Season season) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.heavyImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(win: win, season: season, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.win, required this.season, required this.onDone});

  final DayWin win;
  final Season season;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  // One controller for the whole life of the card, so nothing is left
  // waiting on a timer if the app closes midway.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = dayWinText(widget.win, widget.season);
    final text = Theme.of(context).textTheme;
    final enter = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.18, curve: Curves.easeOutBack),
    );
    final leave = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.86, 1, curve: Curves.easeIn),
    );
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.72),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Opacity(
              opacity: (enter.value.clamp(0.0, 1.0) * (1 - leave.value)).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -24 * (1 - enter.value) - 16 * leave.value),
                child: Transform.scale(scale: 0.9 + 0.1 * enter.value, child: child),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.fromLTRB(18, 14, 22, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inkSoft, AppColors.ink],
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(
                        widget.win == DayWin.perfect ? Icons.auto_awesome_rounded : widget.season.icon,
                        color: AppColors.energyLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleLarge?.copyWith(color: Colors.white)),
                          Text(body, style: text.bodyMedium?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
