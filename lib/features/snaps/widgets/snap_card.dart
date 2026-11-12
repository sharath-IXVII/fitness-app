import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../scan/domain/recognition.dart' show scanRegions;
import '../domain/food_snap.dart';

/// The shareable food snap, in story shape (9:16): the plate fills the top,
/// each dish marked with corner brackets and a name tag, fading into a dark
/// panel with the calories, macro bars and the dishes. Drawn at 360 × 640 and
/// saved at 3× (1080 × 1920).
class SnapCard extends StatelessWidget {
  const SnapCard({super.key, required this.snap, this.photo});

  static const size = Size(360, 640);

  /// Height of the photo area; the panel overlaps its faded bottom.
  static const _photoHeight = 368.0;

  final FoodSnap snap;
  final ImageProvider? photo;

  static const _night = Color(0xFF0D1117);
  static const _ink = Colors.white;
  static const _muted = Color(0xB3FFFFFF);
  static const _protein = Color(0xFF5EC8F2);
  static const _carbs = Color(0xFFF5B85A);
  static const _fibre = Color(0xFF7BD88F);

  static TextStyle _sport(double size, [Color c = _ink, FontWeight w = FontWeight.w700]) =>
      GoogleFonts.chakraPetch(fontSize: size, fontWeight: w, color: c, height: 1.05);
  static TextStyle _body(double size, [Color c = _ink, FontWeight w = FontWeight.w500]) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: 1.2);

  @override
  Widget build(BuildContext context) {
    final items = snap.items.take(4).toList();
    final more = snap.items.length - items.length;
    final total = snap.total;
    final accent = AppColors.primary;
    // Share of energy from each macro, for the bars (4 kcal per gram).
    final macroKcal = (total.protein + total.carbs) * 4;
    double share(double grams) => macroKcal <= 0 ? 0 : (grams * 4 / macroKcal).clamp(0.04, 1.0);

    // Material gives the text its normal style when the card is drawn outside
    // a page (for the saved picture).
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: _night)),
              // A soft glow in the app's (seasonal) colour behind the panel.
              Positioned(
                left: -80,
                right: -80,
                bottom: -140,
                height: 360,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [accent.withValues(alpha: 0.38), accent.withValues(alpha: 0)]),
                  ),
                ),
              ),
              // The plate, edge to edge, with each dish marked.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _photoHeight,
                child: LayoutBuilder(
                  builder: (context, c) {
                    // The photo is square; it covers the area, centred.
                    final side = c.maxWidth > c.maxHeight ? c.maxWidth : c.maxHeight;
                    final dx = (c.maxWidth - side) / 2, dy = (c.maxHeight - side) / 2;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (photo != null)
                          Image(image: photo!, fit: BoxFit.cover, gaplessPlayback: true)
                        else
                          ColoredBox(color: accent.withValues(alpha: 0.25)),
                        for (final item in items)
                          if (_area(item.box, side) case final r?)
                            ..._mark(item.name, r.shift(Offset(dx, dy)), accent, c.maxWidth),
                        // Fade into the panel.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, 0.18, 0.62, 1],
                              colors: [Color(0x80000000), Color(0x00000000), Color(0x00000000), _night],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Top: meal and time, and the wordmark.
              Positioned(
                left: 18,
                right: 18,
                top: 18,
                child: Row(
                  children: [
                    Flexible(
                      child: _glass(
                        Text(
                          '${tr(snap.meal.label).toUpperCase()}  ·  ${DateFormat('d MMM, h:mm a').format(snap.at)}',
                          style: _body(10, _ink, FontWeight.w700).copyWith(letterSpacing: 0.8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'FittArc',
                      style: _sport(
                        20,
                      ).copyWith(letterSpacing: 0.8, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 10)]),
                    ),
                  ],
                ),
              ),
              // Dishes seen only in the whole photo: tags along the bottom of the photo.
              Positioned(
                left: 18,
                right: 18,
                top: _photoHeight - 104,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in items)
                      if (_area(item.box, 1) == null) _tag(item.name, accent),
                  ],
                ),
              ),
              // The panel: calories, macros and the dishes.
              Positioned(
                left: 22,
                right: 22,
                top: _photoHeight - 52,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('THIS PLATE'), style: _body(10, _muted, FontWeight.w700).copyWith(letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('≈ ${total.kcal.round()} kcal', style: _sport(36)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _macro(tr('Protein'), total.protein, share(total.protein), _protein),
                        const SizedBox(width: 12),
                        _macro(tr('Carbs'), total.carbs, share(total.carbs), _carbs),
                        const SizedBox(width: 12),
                        _macro(tr('Fibre'), total.fiber, (total.fiber / 30).clamp(0.04, 1.0), _fibre),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: _body(12.5, _ink, FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(item.portion, style: _body(10.5, _muted), maxLines: 1),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 64,
                              child: Text(
                                '${item.macros.kcal.round()} kcal',
                                style: _body(11, _ink, FontWeight.w700),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (more > 0) Text('+ $more more', style: _body(10.5, _muted)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tr('Snapped with FittArc · fittarc.in'),
                            style: _body(9.5, _muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(tr('Estimates'), style: _body(9.5, _muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where to mark a dish on a [side]-wide square photo, or null when it was
  /// seen only in the whole photo. A rough area from the classifier is large
  /// and overlaps its neighbours, so its middle part is marked.
  static Rect? _area(Rect? b, double side) {
    if (b == null || b == const Rect.fromLTWH(0, 0, 1, 1)) return null;
    if (scanRegions.contains(b)) {
      final c = b.center;
      return Rect.fromCenter(
        center: Offset(c.dx * side, c.dy * side),
        width: b.width * side * 0.6,
        height: b.height * side * 0.6,
      );
    }
    return Rect.fromLTWH(b.left * side, b.top * side, b.width * side, b.height * side).deflate(4);
  }

  /// Corner brackets around the dish and its name tag.
  /// The tag sits inside the box's top corner, on the side with room.
  static List<Widget> _mark(String name, Rect r, Color accent, double width) => [
    Positioned.fromRect(
      rect: r,
      child: CustomPaint(painter: _Brackets(Colors.white)),
    ),
    if (r.center.dx < width * 0.6)
      Positioned(
        left: r.left.clamp(4.0, width) + 8,
        top: r.top.clamp(44.0, _photoHeight) + 8,
        child: _tag(name, accent),
      )
    else
      Positioned(
        right: (width - r.right).clamp(4.0, width) + 8,
        top: r.top.clamp(44.0, _photoHeight) + 8,
        child: _tag(name, accent),
      ),
  ];

  static Widget _tag(String name, Color accent) => Container(
    padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
    decoration: BoxDecoration(
      color: const Color(0xD90D1117),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(name, style: _body(10.5, _ink, FontWeight.w700)),
      ],
    ),
  );

  static Widget _glass(Widget child) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x66000000),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: child,
  );

  static Widget _macro(String label, double grams, double fill, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(grams >= 10 ? '${grams.round()} g' : '${grams.toStringAsFixed(1)} g', style: _sport(17)),
        const SizedBox(height: 2),
        Text(label, style: _body(10, _muted)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 5, color: const Color(0x26FFFFFF)),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(height: 5, color: color),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Four rounded corner brackets, like a camera focus frame.
class _Brackets extends CustomPainter {
  const _Brackets(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final l = (size.shortestSide * 0.22).clamp(10.0, 28.0);
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0)
      ..moveTo(w - l, 0)
      ..lineTo(w, 0)
      ..lineTo(w, l)
      ..moveTo(w, h - l)
      ..lineTo(w, h)
      ..lineTo(w - l, h)
      ..moveTo(l, h)
      ..lineTo(0, h)
      ..lineTo(0, h - l);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Brackets old) => old.color != color;
}
