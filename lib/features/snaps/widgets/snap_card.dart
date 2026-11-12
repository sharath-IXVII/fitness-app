import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../diet/domain/food.dart' show Macros;
import '../../diet/domain/meal_log.dart' show MealType;
import '../../scan/domain/recognition.dart' show scanRegions;
import '../domain/food_snap.dart';

/// The shareable food snap, in story shape (9:16): the plate fills the top,
/// each dish marked with corner brackets and a name tag, fading into a dark
/// panel with the calories, macro bars and the dishes. Drawn at 360 × 640 and
/// saved at 3× (1080 × 1920).
/// Looks for the food snap card.
enum SnapStyle {
  night('Night'),
  glass('Glass'),
  polaroid('Polaroid'),
  plate('Plate');

  const SnapStyle(this.label);

  final String label;
}

class SnapCard extends StatelessWidget {
  const SnapCard({super.key, required this.snap, this.photo, this.style = SnapStyle.polaroid});

  final SnapStyle style;

  /// The wordmark stays faint so the food is the star.
  static const _markAlpha = 0.38;

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
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SizedBox.fromSize(
      size: size,
      child: ClipRect(
        child: switch (style) {
          SnapStyle.night => _nightStyle(),
          SnapStyle.glass => _glassStyle(),
          SnapStyle.polaroid => _polaroid(),
          SnapStyle.plate => _plate(),
        },
      ),
    ),
  );

  Widget _nightStyle() {
    final items = snap.items.take(4).toList();
    final more = snap.items.length - items.length;
    final total = snap.total;
    final accent = AppColors.primary;
    // Share of energy from each macro, for the bars (4 kcal per gram).
    final macroKcal = (total.protein + total.carbs) * 4;
    double share(double grams) => macroKcal <= 0 ? 0 : (grams * 4 / macroKcal).clamp(0.04, 1.0);

    return Stack(
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
              Text('FittArc', style: _sport(20, _ink.withValues(alpha: _markAlpha)).copyWith(letterSpacing: 0.8)),
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
    );
  }

  // ------------------------------------------------------------- shared

  List<SnapItem> get _shown => snap.items.take(4).toList();
  String get _when => '${tr(snap.meal.label).toUpperCase()}  ·  ${DateFormat('d MMM, h:mm a').format(snap.at)}';
  static String _g(double v) => v >= 10 ? '${v.round()} g' : '${v.toStringAsFixed(1)} g';

  Widget _photoWithMarks(double width, double height, {bool marks = true}) {
    final side = width > height ? width : height;
    final dx = (width - side) / 2, dy = (height - side) / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photo != null)
          Image(image: photo!, fit: BoxFit.cover, gaplessPlayback: true)
        else
          ColoredBox(color: AppColors.primary.withValues(alpha: 0.25)),
        if (marks)
          for (final item in _shown)
            if (_area(item.box, side) case final r?)
              ..._mark(item.name, r.shift(Offset(dx, dy)), AppColors.primary, width),
      ],
    );
  }

  static Widget _wordmark(Color color, [double size = 18]) =>
      Text('FittArc', style: _sport(size, color.withValues(alpha: _markAlpha)).copyWith(letterSpacing: 0.8));

  // ------------------------------------------------------------- glass
  /// The photo fills the whole story; a frosted card floats at the bottom.
  Widget _glassStyle() {
    final total = snap.total;
    return Stack(
      children: [
        Positioned.fill(child: _photoWithMarks(size.width, size.height)),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.2, 0.55, 1],
                colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          top: 18,
          child: Row(
            children: [
              Flexible(
                child: _glass(
                  Text(
                    _when,
                    style: _body(10, _ink, FontWeight.w700).copyWith(letterSpacing: 0.8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _wordmark(Colors.white),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0x55FFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('≈ ${total.kcal.round()} kcal', style: _sport(32)),
                        const Spacer(),
                        Text(tr('Estimates'), style: _body(9.5, _muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _chip('${_g(total.protein)} ${tr('Protein').toLowerCase()}', _protein),
                        const SizedBox(width: 6),
                        _chip('${_g(total.carbs)} ${tr('Carbs').toLowerCase()}', _carbs),
                        const SizedBox(width: 6),
                        _chip('${_g(total.fiber)} ${tr('Fibre').toLowerCase()}', _fibre),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final item in _shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: _body(12, _ink, FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('${item.macros.kcal.round()} kcal', style: _body(11, _muted, FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(text, style: _body(10.5, _ink, FontWeight.w700)),
  );

  // ------------------------------------------------------------- polaroid
  /// A light, warm card: the photo as a tilted print, the numbers below.
  Widget _polaroid() {
    final total = snap.total;
    // The app's current (seasonal) palette, so the card matches the app.
    final paper = Color.lerp(AppColors.background, AppColors.primarySoft, 0.45)!;
    final ink = AppColors.textPrimary, soft = AppColors.textSecondary;
    final accent = AppColors.primary;
    Color tint(Color c) => Color.lerp(AppColors.surface, c, 0.24)!;
    Color deep(Color c) => Color.lerp(c, Colors.black, 0.35)!;
    return CustomPaint(
      painter: _Dots(paper, accent.withValues(alpha: 0.09)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _when,
                    style: _body(10, soft, FontWeight.w700).copyWith(letterSpacing: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _wordmark(ink),
              ],
            ),
            const SizedBox(height: 16),
            // The print, taped to the page, with a caption and a sticker.
            SizedBox(
              height: 334,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Transform.rotate(
                    angle: -0.035,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(9, 9, 9, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: ClipRRect(borderRadius: BorderRadius.circular(3), child: _photoWithMarks(280, 280)),
                          ),
                          SizedBox(
                            height: 34,
                            child: Center(
                              child: Text(
                                _caption,
                                style: _body(
                                  13,
                                  const Color(0xFF3A3F45),
                                  FontWeight.w600,
                                ).copyWith(fontStyle: FontStyle.italic, letterSpacing: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Washi tape on the two top corners.
                  Positioned(left: 22, top: -8, child: _tape(accent, -0.6)),
                  Positioned(right: 22, top: -8, child: _tape(AppColors.gold, 0.55)),
                  // A round sticker that sums the plate up.
                  Positioned(right: -6, bottom: 22, child: _sticker(_badge(total), accent)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('≈ ${total.kcal.round()} kcal', style: _sport(34, ink)),
                const Spacer(),
                Text(tr('Estimates'), style: _body(9.5, soft)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _pastel(tr('Protein'), _g(total.protein), tint(accent), deep(accent)),
                const SizedBox(width: 8),
                _pastel(tr('Carbs'), _g(total.carbs), tint(AppColors.gold), deep(AppColors.gold)),
                const SizedBox(width: 8),
                _pastel(tr('Fibre'), _g(total.fiber), tint(AppColors.accent), deep(AppColors.accent)),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in _shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
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
                        style: _body(12, ink, FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${item.macros.kcal.round()} kcal', style: _body(11, soft, FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A friendly line for the bottom of the print.
  String get _caption => switch (snap.meal) {
    MealType.breakfast => tr('Breakfast, sorted.'),
    MealType.lunch => tr('Lunch, sorted.'),
    MealType.snack => tr('Snack o\'clock.'),
    MealType.dinner => tr('Dinner, done right.'),
  };

  /// What the sticker says about the plate (plain description, not advice).
  static String _badge(Macros m) {
    if (m.kcal > 0 && m.protein * 4 / m.kcal >= 0.2) return tr('HIGH PROTEIN');
    if (m.fiber >= 8) return tr('FIBRE RICH');
    if (m.kcal > 0 && m.kcal < 400) return tr('LIGHT MEAL');
    return tr('HOME STYLE');
  }

  static Widget _tape(Color color, double angle) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 62,
      height: 20,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
    ),
  );

  static Widget _sticker(String text, Color color) => Transform.rotate(
    angle: 0.22,
    child: Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(text, textAlign: TextAlign.center, style: _sport(12.5).copyWith(height: 1.0, letterSpacing: 0.4)),
    ),
  );

  static Widget _pastel(String label, String value, Color bg, Color fg) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: _sport(16, fg)),
          Text(label, style: _body(9.5, fg)),
        ],
      ),
    ),
  );

  // ------------------------------------------------------------- plate
  /// Bold colour, the plate as a big circle, a giant calorie number.
  Widget _plate() {
    final total = snap.total;
    final accent = AppColors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(accent, Colors.black, 0.15)!, Color.lerp(accent, Colors.black, 0.55)!],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _when,
                    style: _body(10, _muted, FontWeight.w700).copyWith(letterSpacing: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _wordmark(Colors.white),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: 270,
              height: 270,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14)),
                ],
              ),
              child: ClipOval(child: _photoWithMarks(256, 256, marks: false)),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [for (final item in _shown) _tag(item.name, Colors.white)],
            ),
            const Spacer(),
            Text('${total.kcal.round()}', style: _sport(64).copyWith(height: 0.95)),
            Text(tr('kcal on this plate'), style: _body(12, _muted, FontWeight.w600)),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat(tr('Protein'), _g(total.protein)),
                _stat(tr('Carbs'), _g(total.carbs)),
                _stat(tr('Fibre'), _g(total.fiber)),
              ],
            ),
            const SizedBox(height: 10),
            Text(tr('Estimates · fittarc.in'), style: _body(9, _muted)),
          ],
        ),
      ),
    );
  }

  static Widget _stat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(value, style: _sport(18)),
        Text(label, style: _body(10, _muted)),
      ],
    ),
  );

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

/// A soft dotted paper background.
class _Dots extends CustomPainter {
  const _Dots(this.paper, this.dot);

  final Color paper;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final p = Paint()..color = dot;
    for (var y = 10.0; y < size.height; y += 18) {
      for (var x = (y ~/ 18).isEven ? 10.0 : 19.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.4, p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.paper != paper || old.dot != dot;
}
