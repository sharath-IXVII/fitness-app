import 'food.dart';

const _v = FoodClass.vegan, _d = FoodClass.veg, _e = FoodClass.egg, _n = FoodClass.nonVeg;

Food _f(
  String id,
  String name,
  String serving,
  FoodClass cls,
  double kcal,
  double p,
  double c,
  double f,
  double fib, [
  Set<String> tags = const {},
]) => Food(
  id,
  name,
  serving,
  cls,
  Macros(kcal: kcal, protein: p, carbs: c, fat: f, fiber: fib),
  tags: tags,
);

/// Built-in foods with approximate values per serving, focused on everyday
/// Indian meals plus common staples. Values are typical averages — home
/// recipes vary, which the app says wherever it shows them.
final foods = <Food>[
  // Breads, grains & breakfast
  _f('roti', 'Roti / chapati', '1 medium (40 g)', _v, 120, 3, 18, 3.7, 2),
  _f('paratha', 'Plain paratha', '1 (60 g)', _d, 200, 4, 26, 9, 2.5),
  _f('aloo_paratha', 'Aloo paratha', '1 (100 g)', _d, 290, 6, 40, 12, 3),
  _f('rice', 'White rice, cooked', '1 cup (160 g)', _v, 205, 4.3, 45, 0.4, 0.6),
  _f('brown_rice', 'Brown rice, cooked', '1 cup (160 g)', _v, 215, 5, 45, 1.8, 3.5),
  _f('jeera_rice', 'Jeera rice', '1 cup (160 g)', _d, 250, 4.5, 44, 6, 1),
  _f('idli', 'Idli', '2 pieces', _v, 140, 4, 29, 0.5, 1.5, {'breakfast'}),
  _f('dosa', 'Plain dosa', '1 medium', _v, 170, 4, 29, 4, 1.5, {'breakfast'}),
  _f('masala_dosa', 'Masala dosa', '1', _d, 350, 7, 50, 13, 4, {'breakfast'}),
  _f('upma', 'Upma', '1 cup', _v, 250, 6, 38, 8, 3, {'breakfast'}),
  _f('poha', 'Poha', '1 cup', _v, 270, 5, 45, 8, 2, {'breakfast'}),
  _f('oats', 'Oats porridge (water)', '40 g dry', _v, 150, 5, 27, 2.6, 4, {'breakfast'}),
  _f('oats_milk', 'Oats with milk', '40 g oats + 200 ml milk', _d, 270, 12, 37, 8, 4, {'breakfast'}),
  _f('besan_chilla', 'Besan chilla', '2 pieces', _v, 220, 11, 26, 8, 5, {'breakfast', 'high-protein'}),
  _f('moong_chilla', 'Moong dal chilla', '2 pieces', _v, 200, 13, 26, 5, 6, {'breakfast', 'high-protein'}),
  _f('bread', 'Whole-wheat bread', '2 slices', _v, 160, 8, 28, 2, 4, {'breakfast'}),
  _f('quinoa', 'Quinoa, cooked', '1 cup (185 g)', _v, 220, 8, 39, 3.5, 5),
  _f('pasta', 'Pasta, cooked', '1 cup (140 g)', _v, 220, 8, 43, 1.3, 2.5),
  _f('khichdi', 'Moong dal khichdi', '1 cup', _d, 220, 8, 38, 4, 4),
  _f('veg_biryani', 'Veg biryani', '1 cup', _d, 290, 6, 45, 9, 3),

  // Dals, legumes & soy
  _f('dal', 'Dal (toor / moong)', '1 cup (200 g)', _v, 200, 12, 30, 4, 8, {'high-protein'}),
  _f('rajma', 'Rajma curry', '1 cup', _v, 240, 13, 38, 5, 11, {'high-protein'}),
  _f('chole', 'Chana masala', '1 cup', _v, 270, 13, 40, 7, 11, {'high-protein'}),
  _f('sambar', 'Sambar', '1 cup', _v, 130, 6, 20, 3, 5),
  _f('sprouts', 'Sprouts salad', '1 cup', _v, 100, 7, 17, 0.5, 4, {'snack', 'high-protein'}),
  _f('soya', 'Soya chunks, cooked', '50 g dry', _v, 170, 26, 17, 0.3, 6.5, {'high-protein'}),
  _f('tofu', 'Tofu', '100 g', _v, 145, 15, 3, 9, 1, {'high-protein'}),
  _f('peanuts', 'Peanuts, roasted', '30 g', _v, 170, 7.5, 5, 14, 2.5, {'snack'}),

  // Dairy
  _f('paneer', 'Paneer', '100 g', _d, 265, 18, 3.6, 20, 0, {'high-protein'}),
  _f('paneer_bhurji', 'Paneer bhurji', '1 cup (150 g)', _d, 330, 20, 8, 24, 1, {'high-protein'}),
  _f('palak_paneer', 'Palak paneer', '1 cup', _d, 280, 14, 10, 20, 4, {'high-protein'}),
  _f('curd', 'Curd / dahi', '1 cup (200 g)', _d, 120, 7, 9, 6, 0, {'snack'}),
  _f('greek_yogurt', 'Greek yogurt', '150 g', _d, 130, 15, 6, 5, 0, {'snack', 'high-protein'}),
  _f('milk', 'Milk (toned)', '1 glass (250 ml)', _d, 150, 8, 12, 7.5, 0),
  _f('buttermilk', 'Buttermilk / chaas', '1 glass', _d, 60, 3, 5, 3, 0),
  _f('whey', 'Whey protein', '1 scoop (30 g)', _d, 120, 24, 3, 1.5, 0, {'snack', 'high-protein'}),
  _f('chai', 'Tea with milk & sugar', '1 cup', _d, 90, 2.5, 12, 3, 0),

  // Vegetables & sabzi
  _f('mixed_veg', 'Mixed veg sabzi', '1 cup', _v, 150, 4, 16, 8, 5),
  _f('aloo_sabzi', 'Aloo sabzi', '1 cup', _v, 200, 3, 28, 9, 3),
  _f('bhindi', 'Bhindi fry', '1 cup', _v, 160, 3, 14, 11, 5),
  _f('salad', 'Green salad', '1 bowl', _v, 40, 2, 7, 0.3, 3),
  _f('sweet_potato', 'Sweet potato, boiled', '1 medium', _v, 115, 2, 27, 0.2, 4),

  // Fruit, nuts & snacks
  _f('banana', 'Banana', '1 medium', _v, 105, 1.3, 27, 0.4, 3, {'snack'}),
  _f('apple', 'Apple', '1 medium', _v, 95, 0.5, 25, 0.3, 4.4, {'snack'}),
  _f('orange', 'Orange', '1 medium', _v, 62, 1.2, 15, 0.2, 3, {'snack'}),
  _f('papaya', 'Papaya', '1 cup', _v, 60, 0.7, 16, 0.4, 2.5, {'snack'}),
  _f('dates', 'Dates', '3 pieces', _v, 70, 0.6, 18, 0, 2, {'snack'}),
  _f('almonds', 'Almonds', '20 pieces (28 g)', _v, 165, 6, 6, 14, 3.5, {'snack'}),
  _f('peanut_butter', 'Peanut butter', '2 tbsp', _v, 190, 8, 6, 16, 2, {'snack'}),
  _f('avocado', 'Avocado', '½ fruit', _v, 160, 2, 9, 15, 7),
  _f('protein_bar', 'Protein bar', '1 bar', _d, 200, 20, 22, 7, 5, {'snack', 'high-protein'}),
  _f('samosa', 'Samosa', '1 piece', _v, 260, 4, 30, 14, 2, {'snack'}),
  _f('chole_bhature', 'Chole bhature', '1 plate', _d, 650, 17, 80, 30, 10),

  // Eggs
  _f('boiled_egg', 'Boiled egg', '1 large', _e, 78, 6.3, 0.6, 5.3, 0, {'breakfast', 'snack', 'high-protein'}),
  _f('omelette', 'Omelette', '2 eggs', _e, 190, 13, 1.5, 15, 0, {'breakfast', 'high-protein'}),
  _f('egg_bhurji', 'Egg bhurji', '2 eggs', _e, 210, 13, 4, 16, 1, {'breakfast', 'high-protein'}),
  _f('egg_curry', 'Egg curry', '2 eggs', _e, 280, 14, 8, 21, 2, {'high-protein'}),

  // Chicken, fish & meat
  _f('chicken_breast', 'Chicken breast, grilled', '100 g', _n, 165, 31, 0, 3.6, 0, {'high-protein'}),
  _f('chicken_curry', 'Chicken curry', '1 cup (200 g)', _n, 300, 27, 8, 18, 1, {'high-protein'}),
  _f('tandoori', 'Tandoori chicken', '2 pieces (150 g)', _n, 260, 35, 4, 11, 0, {'high-protein'}),
  _f('chicken_biryani', 'Chicken biryani', '1 cup (250 g)', _n, 400, 20, 50, 13, 2),
  _f('fish_curry', 'Fish curry', '1 cup', _n, 250, 24, 6, 14, 1, {'high-protein'}),
  _f('grilled_fish', 'Grilled fish', '100 g', _n, 140, 26, 0, 4, 0, {'high-protein'}),
  _f('prawns', 'Prawns, cooked', '100 g', _n, 100, 24, 0.2, 0.3, 0, {'high-protein'}),
  _f('mutton_curry', 'Mutton curry', '1 cup', _n, 380, 26, 7, 28, 1, {'high-protein'}),
  _f('tuna', 'Tuna (canned in water)', '100 g', _n, 115, 26, 0, 1, 0, {'high-protein'}),
  _f('butter_chicken', 'Butter chicken', '1 cup (240 g)', _n, 440, 30, 12, 30, 2, {'high-protein'}),
  _f('fried_chicken', 'Fried chicken', '2 pieces (150 g)', _n, 450, 34, 14, 28, 1, {'high-protein'}),
  _f('chicken_nuggets', 'Chicken nuggets', '6 pieces (100 g)', _n, 300, 15, 16, 19, 1),
  _f('cheeseburger', 'Cheeseburger', '1 burger (180 g)', _n, 480, 25, 38, 25, 2),
  _f('hot_dog', 'Hot dog', '1 (100 g)', _n, 290, 11, 24, 17, 1),

  // Dishes the camera can recognise
  _f('dal_makhani', 'Dal makhani', '1 cup (200 g)', _d, 330, 12, 30, 18, 8),
  _f('shahi_paneer', 'Shahi paneer', '1 cup (200 g)', _d, 420, 16, 14, 34, 2),
  _f('paneer_tikka', 'Paneer tikka', '6 pieces (150 g)', _d, 330, 20, 8, 24, 2, {'high-protein'}),
  _f('kofta', 'Malai kofta', '1 cup (200 g)', _d, 320, 8, 18, 24, 4),
  _f('aloo_gobi', 'Aloo gobi', '1 cup (180 g)', _v, 180, 5, 20, 9, 6),
  _f('pakora', 'Pakora', '4 pieces (80 g)', _v, 250, 6, 22, 15, 3, {'snack'}),
  _f('dhokla', 'Dhokla', '4 pieces (100 g)', _v, 160, 6, 24, 4, 2, {'snack', 'breakfast'}),
  _f('dahi_vada', 'Dahi vada', '2 pieces (150 g)', _d, 280, 9, 30, 13, 3, {'snack'}),
  _f('veg_pulao', 'Veg pulao', '1 cup (200 g)', _v, 280, 6, 46, 8, 3),
  _f('fried_rice', 'Veg fried rice', '1 cup (200 g)', _v, 330, 7, 48, 12, 2),
  _f('noodles', 'Veg noodles', '1 plate (250 g)', _v, 380, 9, 55, 13, 4),
  _f('fries', 'French fries', '1 medium (115 g)', _v, 365, 4, 48, 17, 4, {'snack'}),
  _f('veg_sandwich', 'Veg sandwich', '1 sandwich (150 g)', _d, 260, 8, 36, 9, 4),
  _f('cheese_sandwich', 'Cheese sandwich', '1 sandwich (130 g)', _d, 350, 14, 30, 19, 2),
  _f('pizza_slice', 'Pizza', '1 slice (110 g)', _d, 285, 12, 34, 11, 2),
  _f('veggie_burger', 'Veggie burger', '1 burger (180 g)', _d, 380, 14, 45, 16, 6),
  _f('pancake', 'Pancakes', '2 medium (100 g)', _e, 230, 6, 30, 9, 1, {'breakfast'}),
  _f('muesli', 'Muesli with milk', '1 bowl (60 g + milk)', _d, 330, 12, 52, 8, 6, {'breakfast'}),
  _f('kheer', 'Kheer', '1 bowl (150 g)', _d, 230, 6, 34, 8, 0),
  _f('jalebi', 'Jalebi', '2 pieces (50 g)', _d, 190, 1, 32, 7, 0),
  _f('gulab_jamun', 'Gulab jamun', '1 piece (40 g)', _d, 150, 2, 22, 6, 0),
  _f('gajar_halwa', 'Gajar halwa', '1/2 cup (100 g)', _d, 270, 5, 35, 13, 2),
  _f('rasgulla', 'Rasgulla', '2 pieces (100 g)', _d, 190, 4, 38, 2, 0),
  _f('barfi', 'Barfi', '2 pieces (40 g)', _d, 180, 4, 22, 9, 0),
  _f('kulfi', 'Kulfi', '1 stick (70 g)', _d, 170, 4, 20, 8, 0),
];

final foodsById = {for (final f in foods) f.id: f};
