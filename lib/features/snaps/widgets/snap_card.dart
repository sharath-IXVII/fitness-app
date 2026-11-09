import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_logo.dart';
import '../domain/food_snap.dart';

/// The shareable food snap, in story shape (9:16). FittArc's name is at the
/// top, then the plate with each dish marked, the nutrition table and the
/// plate total. Drawn at 360 × 640 and saved at 3× (1080 × 1920).
class SnapCard extends StatelessWidget {
  const SnapCard({super.key, required this.snap, this.photo});

  static const size = Size(360, 640);

  final FoodSnap snap;
  final ImageProvider? photo;

  static const _bg = Color(0xFF1B1714);
  static const _glow = Color(0xFFFFB547);
  static const _ink = Color(0xFFF7EFE6);
  static const _muted = Color(0xFFB9AA9A);

  @override
  Widget build(BuildContext context) {
    final items = snap.items.take(5).toList();
    final total = snap.total;
    TextStyle sport(double size, [FontWeight w = FontWeight.w700]) =>
        GoogleFonts.chakraPetch(fontSize: size, fontWeight: w, color: _ink, height: 1.1);
    TextStyle body(double size, [Color c = _ink, FontWeight w = FontWeight.w500]) =>
        GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: 1.2);

    // Material gives the text its normal style when the card is drawn
    // outside a page (for the saved picture).
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A221C), _bg, Color(0xFF120F0D)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand header: always at the top of the story.
                Row(
                  children: [
                    const AppLogo(size: 34, heroTag: null),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FittArc', style: sport(22)),
                          Text(
                            'FOOD SNAP · ${snap.meal.label.toUpperCase()}',
                            style: body(9.5, _glow, FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(DateFormat('d MMM · h:mm a').format(snap.at), style: body(10, _muted)),
                  ],
                ),
                const SizedBox(height: 12),
                // The plate, with each dish marked.
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final side = c.maxWidth;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (photo != null)
                              Image(image: photo!, fit: BoxFit.cover, gaplessPlayback: true)
                            else
                              const ColoredBox(color: Color(0xFF3A2F27)),
                            for (final (i, item) in items.indexed) ..._mark(item, i, side, body),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: _glow, size: 16),
                    const SizedBox(width: 6),
                    Text('Detected foods', style: body(13, _ink, FontWeight.w700)),
                    const SizedBox(width: 4),
                    Text('(approx.)', style: body(10, _muted)),
                  ],
                ),
                const SizedBox(height: 6),
                _row(['Food', 'Qty', 'kcal', 'Protein', 'Carbs', 'Fibre'], body(9, _muted, FontWeight.w600)),
                for (final item in items)
                  _row([
                    item.name,
                    item.portion,
                    '${item.macros.kcal.round()}',
                    _g(item.macros.protein),
                    _g(item.macros.carbs),
                    _g(item.macros.fiber),
                  ], body(10)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _glow.withValues(alpha: 0.8), width: 1.4),
                    color: _glow.withValues(alpha: 0.08),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: _glow, size: 22),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: Text('≈ ${total.kcal.round()} kcal', style: sport(18))),
                      _total('Protein', _g(total.protein), body),
                      _total('Carbs', _g(total.carbs), body),
                      _total('Fibre', _g(total.fiber), body),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Approximate values from a photo · fittarc.in',
                  textAlign: TextAlign.center,
                  style: body(8.5, _muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _g(double v) => v >= 10 ? '${v.round()} g' : '${v.toStringAsFixed(1)} g';

  /// A glowing frame and a name tag where the dish is; dishes seen only in
  /// the whole photo get a tag in the corner instead.
  List<Widget> _mark(SnapItem item, int i, double side, TextStyle Function(double, [Color, FontWeight]) body) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xF2FFF6EA), borderRadius: BorderRadius.circular(20)),
      child: Text(item.name, style: body(10, const Color(0xFF2A221C), FontWeight.w700)),
    );
    final b = item.box;
    if (b == null) {
      return [Positioned(left: 8, bottom: 8.0 + i * 24, child: tag)];
    }
    // The region the model looked at is large and overlaps its neighbours, so
    // the frame marks its middle part, where the dish most likely is.
    final c = b.center;
    final r = Rect.fromCenter(
      center: Offset(c.dx * side, c.dy * side),
      width: b.width * side * 0.62,
      height: b.height * side * 0.62,
    );
    return [
      Positioned.fromRect(
        rect: r,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE27A), width: 2.2),
          ),
        ),
      ),
      Positioned(left: r.left + 6, top: r.top + 6, child: tag),
    ];
  }

  static Widget _row(List<String> cells, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        for (final (i, c) in cells.indexed)
          Expanded(
            flex: const [7, 6, 3, 4, 4, 4][i],
            child: Text(
              c,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: i < 2 ? TextAlign.left : TextAlign.right,
            ),
          ),
      ],
    ),
  );

  static Widget _total(String label, String value, TextStyle Function(double, [Color, FontWeight]) body) => Expanded(
    flex: 2,
    child: Column(
      children: [
        Text(value, style: body(12, _ink, FontWeight.w700)),
        Text(label, style: body(8.5, _muted)),
      ],
    ),
  );
}
