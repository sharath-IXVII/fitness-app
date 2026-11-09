import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

import '../domain/food_snap.dart';

/// The shareable food snap, in story shape (9:16): the plate with each dish
/// marked and a soft FittArc wordmark, the nutrition table and the plate
/// total. Drawn at 360 × 640 and saved at 3× (1080 × 1920).
class SnapCard extends StatelessWidget {
  const SnapCard({super.key, required this.snap, this.photo});

  static const size = Size(360, 640);

  final FoodSnap snap;
  final ImageProvider? photo;

  // The app's own seasonal colours, so a snap looks like FittArc.
  static Color get _bg => AppColors.background;
  static Color get _glow => AppColors.primary;
  static Color get _ink => AppColors.textPrimary;
  static Color get _muted => AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    final items = snap.items.take(5).toList();
    final total = snap.total;
    TextStyle sport(double size, [FontWeight w = FontWeight.w700]) =>
        GoogleFonts.chakraPetch(fontSize: size, fontWeight: w, color: _ink, height: 1.1);
    TextStyle body(double size, [Color? c, FontWeight w = FontWeight.w500]) =>
        GoogleFonts.inter(fontSize: size, fontWeight: w, color: c ?? _ink, height: 1.2);

    // Material gives the text its normal style when the card is drawn
    // outside a page (for the saved picture).
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surface, _bg],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                              ColoredBox(color: AppColors.surfaceHigh),
                            for (final (i, item) in items.indexed) ..._mark(item, i, side, body),
                            // The only branding: a soft FittArc wordmark inside the photo.
                            Positioned(
                              right: 12,
                              bottom: 10,
                              child: Text(
                                'FittArc',
                                style: sport(17).copyWith(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  letterSpacing: 0.6,
                                  shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: _glow, size: 16),
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
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _glow.withValues(alpha: 0.8), width: 1.4),
                    color: AppColors.primarySoft,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: _glow, size: 22),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: Text('≈ ${total.kcal.round()} kcal', style: sport(18))),
                      _total('Protein', _g(total.protein), body),
                      _total('Carbs', _g(total.carbs), body),
                      _total('Fibre', _g(total.fiber), body),
                    ],
                  ),
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
  List<Widget> _mark(SnapItem item, int i, double side, TextStyle Function(double, [Color?, FontWeight]) body) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(item.name, style: body(10, AppColors.textPrimary, FontWeight.w700)),
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
            border: Border.all(color: AppColors.primary, width: 2.2),
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

  static Widget _total(String label, String value, TextStyle Function(double, [Color?, FontWeight]) body) => Expanded(
    flex: 2,
    child: Column(
      children: [
        Text(value, style: body(12, _ink, FontWeight.w700)),
        Text(label, style: body(8.5, _muted)),
      ],
    ),
  );
}
