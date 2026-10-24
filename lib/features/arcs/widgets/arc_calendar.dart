import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/palette.dart';
import '../../streaks/domain/daily_log.dart';
import '../arc_providers.dart';
import '../domain/arc.dart';

/// What locks a day until it is earned, and how it is broken.
extension ArcLock on Season {
  /// "break the ice", "break the chains", …
  String get unlockVerb => switch (this) {
    Season.winter => 'break the ice',
    Season.spring => 'let it bloom',
    Season.summer => 'put out the fire',
    Season.monsoon => 'make it bloom',
  };

  String get lockedLabel => switch (this) {
    Season.winter => 'Frozen',
    Season.spring => 'Budding',
    Season.summer => 'On fire',
    Season.monsoon => 'Dry',
  };
}

/// The whole arc (three months) as a LeetCode-style grid: one column per
/// week. Every day starts locked in the season's way (ice, chains, fire or
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
              child: Text('Go to arc', style: text.titleLarge),
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
    // Previewing another arc's look shows its blocks on the current arc too.
    final season = _back == 0 ? ref.watch(themeSeasonProvider) : period.season;
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
              label: 'Previous arc',
              onTap: _back < maxBack ? () => _goTo(_back + 1) : null,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Choose arc',
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
              label: 'Next arc',
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

/// One day of an arc. Locked (ice, chains, fire or dry soil) until 3 of 5
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

  bool get unlocked => count >= 3;

  @override
  Widget build(BuildContext context) {
    final p = season.palette;
    Widget body;
    if (future || !counted) {
      body = _Plain(day: day, faded: !counted && !future, palette: p);
    } else {
      body = AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: 1.35, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: CustomPaint(
          key: ValueKey(unlocked),
          painter: _CellPainter(season, p, count: count, day: day),
          size: Size.infinite,
        ),
      );
    }
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

class _Plain extends StatelessWidget {
  const _Plain({required this.day, required this.faded, required this.palette});

  final int day;
  final bool faded;
  final Palette palette;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: faded ? palette.surfaceHigh.withValues(alpha: 0.5) : Colors.white,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: palette.stroke),
    ),
    child: FittedBox(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Text(
          '$day',
          style: TextStyle(color: palette.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
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
    if (season == Season.monsoon) {
      // A few blades of grass along the bottom.
      final g = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = size.width * 0.05
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < 5; i++) {
        final x = size.width * i / 5;
        canvas.drawLine(Offset(x, size.height), Offset(x + size.width * 0.04, size.height * 0.82), g);
      }
    }
    if (count == 5) {
      // Perfect day: a small star in the corner.
      _star(canvas, Offset(size.width * 0.8, size.height * 0.2), size.width * 0.12, p.energyLight);
    }
    _number(canvas, size, Colors.white);
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

  void _buds(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [p.inkSoft, p.ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    // Three buds across the cell; each goal done opens one into a blossom.
    final w = size.width, h = size.height;
    final bud = Paint()..color = const Color(0xFF8E6A79);
    final bloom = Paint()..color = p.energyLight;
    for (var i = 0; i < 3; i++) {
      final c = Offset(w * (0.2 + i * 0.3), h * 0.5);
      if (i < count) {
        for (var k = 0; k < 5; k++) {
          final a = k * 2 * math.pi / 5;
          canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.07, w * 0.065, bloom);
        }
        canvas.drawCircle(c, w * 0.04, Paint()..color = p.energy);
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.13, height: h * 0.2), bud);
      }
    }
  }

  void _fire(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFB8360F), Color(0xFFF07A1A), Color(0xFFFFC145)],
        ).createShader(rect),
    );
    // Flame tongues.
    final flame = Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.85);
    for (final (x, top) in [(0.3, 0.3), (0.62, 0.18), (0.85, 0.42)]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * (x - 0.13), h)
          ..quadraticBezierTo(w * (x - 0.12), h * (top + 0.25), w * x, h * top)
          ..quadraticBezierTo(w * (x + 0.12), h * (top + 0.25), w * (x + 0.13), h)
          ..close(),
        flame,
      );
    }
    // Water rises with each goal; at 3 it puts the fire out.
    if (count > 0) {
      final level = h * (1 - count / 3);
      final water = Path()
        ..moveTo(0, level)
        ..quadraticBezierTo(w * 0.25, level - h * 0.06, w * 0.5, level)
        ..quadraticBezierTo(w * 0.75, level + h * 0.06, w, level)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(water, Paint()..color = const Color(0xFF2EA3D8).withValues(alpha: 0.9));
    }
  }

  void _soil(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFC9A57A));
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, w * 0.035)
      ..color = const Color(0xFF8E6A43);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.3)
        ..lineTo(w * 0.35, h * 0.45)
        ..lineTo(w * 0.3, h * 0.8)
        ..moveTo(w * 0.35, h * 0.45)
        ..lineTo(w * 0.75, h * 0.35)
        ..lineTo(w, h * 0.55)
        ..moveTo(w * 0.75, h * 0.35)
        ..lineTo(w * 0.7, 0),
      crack,
    );
    // A sprout grows with each goal.
    if (count > 0) {
      final stem = Paint()
        ..color = const Color(0xFF3E9A5B)
        ..strokeWidth = math.max(1, w * 0.07)
        ..strokeCap = StrokeCap.round;
      final top = h * (count == 1 ? 0.62 : 0.38);
      canvas.drawLine(Offset(w * 0.5, h * 0.88), Offset(w * 0.5, top), stem);
      final leaf = Paint()..color = const Color(0xFF55B872);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.38, top + h * 0.06), width: w * 0.24, height: h * 0.12),
        leaf,
      );
      if (count >= 2) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w * 0.62, top + h * 0.02), width: w * 0.24, height: h * 0.12),
          leaf,
        );
      }
    }
  }

  void _number(Canvas canvas, Size size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$day',
        style: TextStyle(color: color, fontSize: size.height * 0.48, fontWeight: FontWeight.w800, height: 1),
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
