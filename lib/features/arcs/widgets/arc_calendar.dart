import 'dart:math' as math;

import '../../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/palette.dart';
import '../../streaks/domain/daily_log.dart';
import '../arc_providers.dart';
import '../domain/arc.dart';

/// What locks a day until it is earned, and how it is broken.
extension ArcLock on Season {
  /// "break the ice", "break the ice", "let it bloom", …
  String get unlockVerb => switch (this) {
    Season.winter => 'break the ice',
    Season.spring => 'let it bloom',
    Season.summer => 'let the sun shine',
    Season.monsoon => 'break the storm',
  };

  String get lockedLabel => switch (this) {
    Season.winter => 'Frozen',
    Season.spring => 'Budding',
    Season.summer => 'Hazy',
    Season.monsoon => 'Dry',
  };
}

/// The whole arc (three months) as a LeetCode-style grid: one column per
/// week. Every day starts locked in the season's way (ice, buds, fire or
/// dry soil) and breaks open, showing its date, once 3 of 5 goals are done.
class ArcCalendar extends ConsumerStatefulWidget {
  const ArcCalendar({super.key, required this.scores});

  final Map<DateTime, DayScore> scores;

  @override
  ConsumerState<ArcCalendar> createState() => _ArcCalendarState();
}

class _ArcCalendarState extends ConsumerState<ArcCalendar> {
  /// 0 = the current arc, 1 = the one before, …
  int _back = 0;
  DateTime? _selected;

  static const _gap = 3.0;
  static const _labelW = 16.0;

  void _goTo(int back) => setState(() {
    _back = back;
    _selected = null;
  });

  ArcPeriod _period(ArcPeriod now) {
    var p = now;
    for (var i = 0; i < _back; i++) {
      p = p.previous;
    }
    return p;
  }

  /// Arcs that can be browsed: back to the one the user joined in.
  int _maxBack(ArcPeriod now, DateTime firstUse) {
    var n = 0;
    var p = now;
    while (p.start.isAfter(firstUse) && n < 40) {
      p = p.previous;
      n++;
    }
    return n;
  }

  Future<void> _pick(ArcPeriod now, int maxBack) async {
    final text = Theme.of(context).textTheme;
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(tr('Go to arc'), style: text.titleLarge),
            ),
            for (var i = 0; i <= maxBack; i++)
              Builder(
                builder: (_) {
                  var p = now;
                  for (var k = 0; k < i; k++) {
                    p = p.previous;
                  }
                  return ListTile(
                    leading: Icon(p.season.icon, color: p.season.palette.primary),
                    title: Text(p.label, style: text.titleSmall),
                    trailing: Text(p.season.months, style: text.bodySmall),
                    selected: i == _back,
                    onTap: () => Navigator.pop(c, i),
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (picked != null) _goTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = ref.watch(currentArcProvider);
    final today = ref.watch(todayProvider);
    final firstUse = ref.watch(firstUseProvider);
    final maxBack = _maxBack(now, firstUse);
    final period = _period(now);
    final season = period.season;
    final offset = period.start.weekday - 1;
    final cols = ((offset + period.totalDays) / 7).ceil();
    final result = ArcResult.of(period, widget.scores, firstUse, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Arrow(
              icon: Icons.chevron_left_rounded,
              label: tr('Previous arc'),
              onTap: _back < maxBack ? () => _goTo(_back + 1) : null,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: tr('Choose arc'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pick(now, maxBack),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(period.season.icon, size: 18, color: period.season.palette.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(period.label, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                        ),
                        Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _Arrow(
              icon: Icons.chevron_right_rounded,
              label: tr('Next arc'),
              onTap: _back > 0 ? () => _goTo(_back - 1) : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final cell = ((box.maxWidth - _labelW - _gap * (cols - 1)) / cols).floorToDouble();
            final step = cell + _gap;
            return SizedBox(
              height: 14 + step * 7,
              child: Stack(
                children: [
                  // Month names above the week where each month starts.
                  for (var m = 0; m < 3; m++)
                    Positioned(
                      left:
                          _labelW +
                          step *
                              ((offset + _days(period.start, DateTime(period.year, period.season.firstMonth + m))) ~/
                                  7),
                      top: 0,
                      child: Text(
                        DateFormat.MMM().format(DateTime(period.year, period.season.firstMonth + m)),
                        style: text.labelSmall?.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  for (final (r, l) in [(0, 'M'), (2, 'W'), (4, 'F')])
                    Positioned(
                      left: 0,
                      top: 14 + step * r + (cell - 12) / 2,
                      child: Text(l, style: text.labelSmall?.copyWith(color: AppColors.textMuted, fontSize: 10)),
                    ),
                  for (var i = 0; i < period.totalDays; i++)
                    Builder(
                      builder: (context) {
                        final day = DateTime(period.start.year, period.start.month, period.start.day + i);
                        final pos = offset + i;
                        return Positioned(
                          left: _labelW + step * (pos ~/ 7),
                          top: 14 + step * (pos % 7),
                          width: cell,
                          height: cell,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selected = _selected == day ? null : day);
                            },
                            child: ArcDayCell(
                              season: season,
                              day: day.day,
                              count: widget.scores[day]?.count ?? 0,
                              future: day.isAfter(today),
                              counted: !day.isBefore(result.from),
                              today: day == today,
                              selected: day == _selected,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _caption(season, result, today),
            key: ValueKey('$_selected-$_back'),
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  String _caption(Season season, ArcResult r, DateTime today) {
    final d = _selected;
    if (d == null) {
      final verb = season.unlockVerb;
      return '${r.active} days unlocked · hit 3 of 5 goals to $verb';
    }
    final count = widget.scores[d]?.count ?? 0;
    final when = DateFormat('EEEE, d MMM').format(d);
    if (d.isAfter(today)) return '$when · still to come';
    if (count >= 3) return '$when · $count of 5 goals · unlocked';
    final verb = season.unlockVerb;
    return d == today
        ? '$when · $count of 5 goals · ${3 - count} more to $verb'
        : '$when · $count of 5 goals · stayed ${season.lockedLabel.toLowerCase()}';
  }

  static int _days(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    style: IconButton.styleFrom(backgroundColor: onTap == null ? null : AppColors.surfaceHigh),
    icon: Icon(icon, color: onTap == null ? AppColors.stroke : AppColors.textPrimary),
  );
}

/// One day of an arc. Locked (ice, buds, fire or dry soil) until 3 of 5
/// goals are done; partial progress already shows (cracks, broken links,
/// rising water, a sprout). Unlocking plays a short burst.
class ArcDayCell extends StatelessWidget {
  const ArcDayCell({
    super.key,
    required this.season,
    required this.day,
    required this.count,
    this.future = false,
    this.counted = true,
    this.today = false,
    this.selected = false,
  });

  final Season season;
  final int day;

  /// Goals done, 0–5.
  final int count;
  final bool future;

  /// False before the user joined: shown plain.
  final bool counted;
  final bool today;
  final bool selected;

  /// Days that are still to come, or before the user joined, never open.
  int get _goals => (future || !counted) ? 0 : count;

  bool get unlocked => _goals >= 3;

  @override
  Widget build(BuildContext context) {
    final p = season.palette;
    // Every day of the arc starts locked, numbers hidden; it breaks open
    // (and shows its date) only once earned.
    Widget body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: Tween(begin: 1.35, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: CustomPaint(
        key: ValueKey(unlocked),
        painter: _CellPainter(season, p, count: _goals, day: day),
        size: Size.infinite,
      ),
    );
    if (!counted && !future) body = Opacity(opacity: 0.55, child: body);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: today || selected
            ? Border.all(color: selected ? p.textPrimary : p.energy, width: selected ? 1.6 : 2)
            : null,
      ),
      child: body,
    );
  }
}

class _CellPainter extends CustomPainter {
  _CellPainter(this.season, this.p, {required this.count, required this.day});

  final Season season;
  final Palette p;
  final int count;
  final int day;

  bool get unlocked => count >= 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.save();
    canvas.clipRRect(rr);
    if (unlocked) {
      _unlocked(canvas, size);
    } else {
      switch (season) {
        case Season.winter:
          _ice(canvas, size);
        case Season.spring:
          _buds(canvas, size);
        case Season.summer:
          _fire(canvas, size);
        case Season.monsoon:
          _soil(canvas, size);
      }
    }
    canvas.restore();
  }

  /// Revealed day: the season's colour, deeper for more goals.
  void _unlocked(Canvas canvas, Size size) {
    final fill = p.heat[(count + 1).clamp(2, 4)];
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    if (count == 5) {
      // Perfect day: a small star in the corner.
      _star(canvas, Offset(size.width * 0.8, size.height * 0.2), size.width * 0.12, p.energyLight);
    }
    _number(canvas, size, fill.computeLuminance() > 0.55 ? p.textPrimary : Colors.white);
  }

  void _ice(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4FAFF), Color(0xFFCFE6F7), Color(0xFFA9D0EE)],
        ).createShader(rect),
    );
    // Shine.
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.22), Offset(size.width * 0.45, size.height * 0.22), shine);
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.22), Offset(size.width * 0.2, size.height * 0.4), shine);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8DBDE3),
    );
    // Cracks spread with each goal done.
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, size.width * 0.04)
      ..color = const Color(0xFF5C93C4);
    final w = size.width, h = size.height;
    if (count >= 1) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.55, 0)
          ..lineTo(w * 0.48, h * 0.35)
          ..lineTo(w * 0.62, h * 0.55)
          ..lineTo(w * 0.5, h),
        crack,
      );
    }
    if (count >= 2) {
      canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.62)
          ..lineTo(w * 0.3, h * 0.55)
          ..lineTo(w * 0.48, h * 0.35)
          ..moveTo(w * 0.62, h * 0.55)
          ..lineTo(w, h * 0.7),
        crack,
      );
    }
  }

  /// A soft glossy tile like the winter ice: gradient, a shine in the corner
  /// and a thin border.
  void _tile(Canvas canvas, Size size, List<Color> colors, Color border) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.22), Offset(size.width * 0.45, size.height * 0.22), shine);
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.22), Offset(size.width * 0.2, size.height * 0.4), shine);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  /// Rise of Revolution: a baby-pink tile; each goal done opens a petal.
  void _buds(Canvas canvas, Size size) {
    _tile(canvas, size, const [Color(0xFFFFF6FA), Color(0xFFFFE2EC), Color(0xFFFBCADD)], const Color(0xFFF3B4CB));
    if (count == 0) return;
    final w = size.width, h = size.height;
    final c = Offset(w * 0.62, h * 0.62);
    final petal = Paint()..color = const Color(0xFFF48FB1).withValues(alpha: 0.9);
    final petals = count == 1 ? 2 : 5;
    for (var k = 0; k < petals; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / 5;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.12, w * 0.085, petal);
    }
    canvas.drawCircle(c, w * 0.06, Paint()..color = const Color(0xFFFFE08A));
  }

  /// Summer Arc: a pale sunny tile; the sun appears and brightens with
  /// each goal (3 lets the sun shine).
  void _fire(Canvas canvas, Size size) {
    _tile(canvas, size, const [Color(0xFFFFFBEC), Color(0xFFFFECBE), Color(0xFFFFDB96)], const Color(0xFFF2BE6E));
    final w = size.width;
    final c = Offset(w * 0.66, size.height * 0.66);
    final r = w * [0.08, 0.11, 0.14][count.clamp(0, 2)];
    final color = [const Color(0x99FFD678), const Color(0xE6FFBE46), const Color(0xFFFFA028)][count.clamp(0, 2)];
    final ray = Paint()
      ..color = color
      ..strokeWidth = math.max(1, w * 0.045)
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 1.4, c + d * r * 1.95, ray);
    }
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  /// Thunder Arc: a plain grey-blue tile with a small bolt in the corner.
  /// It grows darker with each goal, like a storm building, until it breaks.
  void _soil(Canvas canvas, Size size) {
    const shades = [
      [Color(0xFFF4F6FB), Color(0xFFDCE2F0), Color(0xFFC8D1E6)],
      [Color(0xFFDDE3F0), Color(0xFFC3CCE2), Color(0xFFAAB6D4)],
      [Color(0xFFBFC9E0), Color(0xFFA2AFCE), Color(0xFF8796BC)],
    ];
    const borders = [Color(0xFFAAB6D6), Color(0xFF93A1C6), Color(0xFF7584B0)];
    final k = count.clamp(0, 2);
    _tile(canvas, size, shades[k], borders[k]);
    _bolt(canvas, size, scale: 1.25, color: const Color(0xFFF2B705));
  }

  /// A small lightning bolt in the bottom-right corner.
  void _bolt(Canvas canvas, Size size, {double scale = 1, Color color = const Color(0xFFFFD650)}) {
    final w = size.width * scale, h = size.height * scale;
    final o = Offset(size.width - w * 0.36, size.height - h * 0.46);
    canvas.drawPath(
      Path()
        ..moveTo(o.dx + w * 0.15, o.dy)
        ..lineTo(o.dx + w * 0.03, o.dy + h * 0.22)
        ..lineTo(o.dx + w * 0.11, o.dy + h * 0.22)
        ..lineTo(o.dx + w * 0.05, o.dy + h * 0.38)
        ..lineTo(o.dx + w * 0.22, o.dy + h * 0.15)
        ..lineTo(o.dx + w * 0.14, o.dy + h * 0.15)
        ..lineTo(o.dx + w * 0.21, o.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  void _number(Canvas canvas, Size size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$day',
        // The app's bundled sport font, so the date looks the same on every phone.
        style: GoogleFonts.chakraPetch(
          color: color,
          fontSize: size.height * 0.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CellPainter old) => old.count != count || old.season != season || old.day != day;
}
