import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../../diet/domain/food.dart';

/// One guess from the on-device food model, with the matching food from the
/// app's nutrition list when there is one.
class FoodGuess {
  const FoodGuess({required this.label, required this.score, this.food, this.box});

  final String label;

  /// Roughly where on the photo the dish was seen, as fractions (0–1) of the
  /// square plate photo; null when only the whole photo showed it.
  final Rect? box;

  /// 0–1.
  final double score;
  final Food? food;

  int get percent => (score * 100).round();
}

/// Reads the model's label map ("id,name" CSV with a header row; names may
/// be quoted). The list index is the class id.
List<String> parseLabels(String csv) {
  final out = <String>[];
  for (final raw in csv.split('\n').skip(1)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final comma = line.indexOf(',');
    if (comma < 0) continue;
    var name = line.substring(comma + 1).trim();
    if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
      name = name.substring(1, name.length - 1).replaceAll('""', '"');
    }
    final id = int.tryParse(line.substring(0, comma));
    if (id == null) continue;
    while (out.length < id) {
      out.add('');
    }
    out.add(name);
  }
  return out;
}

/// Turns raw (possibly quantized) scores into probabilities that sum to 1.
List<double> normalizeScores(List<num> raw, {double scale = 1, int zeroPoint = 0}) {
  final v = [for (final r in raw) math.max(0.0, (r - zeroPoint) * scale)];
  final sum = v.fold(0.0, (a, b) => a + b);
  return sum <= 0 ? v : [for (final x in v) x / sum];
}

/// The [k] best classes above [minScore], skipping the background class 0.
List<(int, double)> topK(List<double> scores, {int k = 5, double minScore = 0.02}) {
  final idx = [for (var i = 1; i < scores.length; i++) i]..sort((a, b) => scores[b].compareTo(scores[a]));
  return [
    for (final i in idx.take(k))
      if (scores[i] >= minScore) (i, scores[i]),
  ];
}

/// The parts of the square plate photo the model looks at: the whole photo
/// first, then four overlapping corners and the centre (fractions, 0–1).
const scanRegions = <Rect>[
  Rect.fromLTWH(0, 0, 1, 1),
  Rect.fromLTWH(0, 0, 0.6, 0.6),
  Rect.fromLTWH(0.4, 0, 0.6, 0.6),
  Rect.fromLTWH(0, 0.4, 0.6, 0.6),
  Rect.fromLTWH(0.4, 0.4, 0.6, 0.6),
  Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
];

/// Merges guesses from the whole photo ([views] first) and zoomed-in
/// regions of it, so a plate with several dishes yields each of them. A
/// label keeps its best score; region guesses count a little less than the
/// whole photo and must be fairly confident to be listed at all. Each result
/// also names the region it scored best in (0 is the whole photo), which
/// marks roughly where the dish sits.
List<(String, double, int)> mergeViews(
  List<List<(String, double)>> views, {
  double regionWeight = 0.85,
  double minRegionScore = 0.12,
  int k = 8,
}) {
  final best = <String, double>{};
  final where = <String, int>{};
  // The region where the dish scored highest, before weighting.
  final raw = <String, double>{};
  for (final (v, guesses) in views.indexed) {
    for (final (label, score) in guesses) {
      if (v > 0 && score < minRegionScore) continue;
      final s = v == 0 ? score : score * regionWeight;
      if (s > (best[label] ?? 0)) best[label] = s;
      if (v > 0 && score > (raw[label] ?? 0)) {
        raw[label] = score;
        where[label] = v;
      }
    }
  }
  final out = [for (final e in best.entries) (e.key, e.value, where[e.key] ?? 0)]..sort((a, b) => b.$2.compareTo(a.$2));
  return out.take(k).toList();
}

/// Model label (lower-case) → food id in the nutrition list.
const _exact = {
  'idli': 'idli',
  'samosa': 'samosa',
  'sambar': 'sambar',
  'upma': 'upma',
  'poha': 'poha',
  'dosa': 'dosa',
  'masala dosa': 'masala_dosa',
  'khichdi': 'khichdi',
  'rajma': 'rajma',
  'chana masala': 'chole',
  'chole bhature': 'chole_bhature',
  'dal makhani': 'dal_makhani',
  'dal bhat': 'dal',
  'dal': 'dal',
  'palak paneer': 'palak_paneer',
  'shahi paneer': 'shahi_paneer',
  'paneer tikka': 'paneer_tikka',
  'kofta': 'kofta',
  'malai kofta': 'kofta',
  'aloo gobi': 'aloo_gobi',
  'aloo paratha': 'aloo_paratha',
  'mughlai paratha': 'paratha',
  'paratha': 'paratha',
  'roti': 'roti',
  'chapati': 'roti',
  'pakora': 'pakora',
  'dhokla': 'dhokla',
  'dahi vada': 'dahi_vada',
  'kosambari': 'sprouts',
  'butter chicken': 'butter_chicken',
  'chicken curry': 'chicken_curry',
  'chicken karahi': 'chicken_curry',
  'mutton curry': 'mutton_curry',
  'fish head curry': 'fish_curry',
  'fish curry': 'fish_curry',
  'tandoori chicken': 'tandoori',
  'egg curry': 'egg_curry',
  'white rice': 'rice',
  'steamed rice': 'rice',
  'pilaf': 'veg_pulao',
  'pulao': 'veg_pulao',
  'kheer': 'kheer',
  'rice pudding': 'kheer',
  'chhena kheeri': 'kheer',
  'jalebi': 'jalebi',
  'gulab jamun': 'gulab_jamun',
  'curd': 'curd',
  'chole': 'chole',
  'paneer curry': 'shahi_paneer',
  'gajar ka halwa': 'gajar_halwa',
  'carrot halwa': 'gajar_halwa',
  'halwa': 'gajar_halwa',
  'bhindi masala': 'bhindi',
  'aloo matar': 'aloo_sabzi',
  'dum aloo': 'aloo_sabzi',
  'baingan bharta': 'mixed_veg',
  'mixed vegetable curry': 'mixed_veg',
  'chhena jalebi': 'jalebi',
  'rasgulla': 'rasgulla',
  'barfi': 'barfi',
  'kulfi': 'kulfi',
  'omelette': 'omelette',
  'tea egg': 'boiled_egg',
  'soy egg': 'boiled_egg',
  'pancake': 'pancake',
  'muesli': 'muesli',
  'cheeseburger': 'cheeseburger',
  'veggie burger': 'veggie_burger',
  'fried chicken': 'fried_chicken',
  'crispy fried chicken': 'fried_chicken',
  'chicken nugget': 'chicken_nuggets',
  'chicken fingers': 'chicken_nuggets',
  'hot dog': 'hot_dog',
  'home fries': 'fries',
  'cheese fries': 'fries',
  'french fries': 'fries',
  'cheese sandwich': 'cheese_sandwich',
  'sandwich': 'veg_sandwich',
  'garden salad': 'salad',
  'chinese noodles': 'noodles',
  'chow mein': 'noodles',
};

/// Broader rules for labels not listed exactly (checked in order).
const _contains = [
  ('biryani', 'veg_biryani'),
  ('fried rice', 'fried_rice'),
  ('pizza', 'pizza_slice'),
  ('veggie burger', 'veggie_burger'),
  ('burger', 'cheeseburger'),
  ('fried chicken', 'fried_chicken'),
  ('noodle', 'noodles'),
  ('fries', 'fries'),
  ('sandwich', 'veg_sandwich'),
  ('salad', 'salad'),
  ('omelette', 'omelette'),
  ('pancake', 'pancake'),
  ('paratha', 'paratha'),
  ('jamun', 'gulab_jamun'),
  ('halwa', 'gajar_halwa'),
  ('sabzi', 'mixed_veg'),
  ('aloo', 'aloo_sabzi'),
  ('potato curry', 'aloo_sabzi'),
  ('vegetable curry', 'mixed_veg'),
  ('roti', 'roti'),
  // Breads the model often calls by another name.
  ('chapati', 'roti'),
  ('phulka', 'roti'),
  ('flatbread', 'roti'),
  ('naan', 'roti'),
  ('tortilla', 'roti'),
  ('pita', 'roti'),
  ('puri', 'paratha'),
  ('bhatura', 'chole_bhature'),
  ('lentil', 'dal'),
  ('egg', 'boiled_egg'),
  ('curd', 'curd'),
  ('yogurt', 'curd'),
  ('rice', 'rice'),
];

/// The food in [byId] that best matches a model [label], or null.
Food? matchFood(String label, Map<String, Food> byId) {
  final l = label.toLowerCase().trim();
  // The app's own detector uses food ids as labels.
  final own = byId[l];
  if (own != null) return own;
  final exact = _exact[l];
  if (exact != null) return byId[exact];
  for (final (needle, id) in _contains) {
    if (l.contains(needle)) return byId[id];
  }
  // Finally, a food whose own name is the label.
  for (final f in byId.values) {
    if (f.name.toLowerCase() == l) return f;
  }
  return null;
}
