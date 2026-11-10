import '../../core/i18n/i18n.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_store.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/beta_tag.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../diet/diet_providers.dart';
import '../diet/domain/food.dart';
import '../diet/domain/meal_log.dart';
import '../diet/widgets/food_search_sheet.dart';
import '../diet/widgets/sheet_frame.dart';
import '../profile/profile_providers.dart';
import '../snaps/domain/food_snap.dart';
import '../snaps/snap_screen.dart';
import '../snaps/snaps_providers.dart';
import 'domain/recognition.dart';
import 'domain/scan_result.dart';
import 'food_recognizer.dart';
import 'widgets/plate_result.dart';

typedef PickedImage = ({Uint8List bytes, String mediaType});

/// Opens the camera or gallery and returns a downscaled JPEG. Overridden in tests.
final pickImageProvider = Provider<Future<PickedImage?> Function(ImageSource)>(
  (ref) => (source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
    if (x == null) return null;
    final type = x.mimeType ?? (x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return (bytes: await x.readAsBytes(), mediaType: type);
  },
);

enum _Phase { pick, scanning, result }

/// Photograph a plate: the dish is recognised on the phone (free, offline,
/// nothing uploaded), matched to the app's nutrition list, and the user
/// confirms the dish and portion before logging it.
class ScanFoodScreen extends ConsumerStatefulWidget {
  const ScanFoodScreen({super.key, this.meal = MealType.lunch});

  final MealType meal;

  @override
  ConsumerState<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends ConsumerState<ScanFoodScreen> {
  late MealType _meal = widget.meal;
  _Phase _phase = _Phase.pick;
  PickedImage? _image;
  List<FoodGuess> _guesses = [];
  List<ScannedItem> _items = [];
  String? _error;

  /// A guess is added automatically only when the model is fairly sure.
  /// Everyday dishes offered when the model can't tell, one tap each.
  static const _commonDishes = [
    'roti',
    'rice',
    'dal',
    'mixed_veg',
    'aloo_sabzi',
    'gulab_jamun',
    'gajar_halwa',
    'rajma',
    'chole',
    'paratha',
    'idli',
    'dosa',
    'boiled_egg',
    'chicken_curry',
    'aloo_gobi',
    'salad',
  ];

  static const autoAddScore = 0.12;
  static const maxAutoAdd = 4;

  Future<void> _pick(ImageSource source) async {
    final classify = ref.read(foodClassifierProvider).value;
    if (classify == null) return;
    PickedImage? img;
    try {
      img = await ref.read(pickImageProvider)(source);
    } on PlatformException {
      setState(() => _error = 'Allow camera and photo access in Settings to scan food.');
      return;
    }
    if (img == null || !mounted) return;
    setState(() {
      _image = img;
      _phase = _Phase.scanning;
      _error = null;
    });
    try {
      final guesses = await recognizeFood(ref, classify, img.bytes);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      // Each confident dish on the plate, once (two labels can map to one food).
      final seen = <String>{};
      final best = guesses
          .where((g) => g.food != null && g.score >= autoAddScore && seen.add(g.food!.id))
          .take(maxAutoAdd)
          .toList();
      // Nothing confident: still put the model's best food match on the plate
      // so the user only has to confirm or change it.
      if (best.isEmpty) {
        final top = guesses.where((g) => g.food != null && g.score >= 0.04).firstOrNull;
        if (top != null) best.add(top);
      }
      setState(() {
        _guesses = guesses;
        _items = [for (final g in best) ScannedItem.fromFood(g.food!, g.score, box: g.box)];
        _phase = _Phase.result;
      });
    } catch (e) {
      debugPrint('food recognition failed: $e');
      if (!mounted) return;
      setState(() {
        _error = "Couldn't read that photo. Try again, or add the food manually.";
        _phase = _Phase.pick;
      });
    }
  }

  void _retake() => setState(() {
    _phase = _Phase.pick;
    _guesses = [];
    _items = [];
  });

  Future<void> _log() async {
    final base = MealLogNotifier.newId();
    // The photo stays on this phone, attached to the first item of the meal.
    // It's written in the background so logging never waits on storage.
    final photo = _image != null && PhotoStore.supported ? '$base.jpg' : null;
    if (photo != null) unawaited(PhotoStore.save(photo, _image!.bytes));
    await ref.read(mealLogProvider.notifier).addAll([
      for (final (i, item) in _items.indexed)
        MealEntry(
          id: '$base$i',
          meal: _meal,
          name: item.name,
          servings: item.factor,
          perServing: item.macros,
          serving: item.portion.isEmpty ? null : item.portion,
          source: 'scan',
          photo: i == 0 ? photo : null,
        ),
    ]);
    // Every scan also becomes a food snap, kept on this phone.
    await ref
        .read(snapsProvider.notifier)
        .add(
          FoodSnap(
            id: base,
            at: DateTime.now(),
            meal: _meal,
            photo: photo,
            items: [
              for (final item in _items)
                SnapItem(
                  name: item.name,
                  portion: portionText(item.portion, item.factor),
                  macros: item.scaled,
                  box: item.box,
                ),
            ],
          ),
        );
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${_items.length} ${_items.length == 1 ? 'item' : 'items'} to ${_meal.label.toLowerCase()}',
        ),
      ),
    );
    context.pushReplacement(Routes.snap, extra: SnapArgs(base, photo: _image?.bytes));
  }

  /// One tap to put a likely dish on the plate: the model's other guesses
  /// first, then everyday Indian dishes.
  Widget _quickAdd(TextTheme text) {
    final byId = ref.read(allFoodsByIdProvider);
    final have = {for (final i in _items) i.name};
    final seen = <String>{};
    final options = [
      for (final g in _guesses)
        if (g.food != null) g.food!,
      for (final id in _commonDishes) ?byId[id],
    ].where((f) => !have.contains(f.name) && seen.add(f.id)).take(10).toList();
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Also on your plate? Tap to add'), style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in options)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(f.name),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _items.add(ScannedItem.fromFood(f, 1)));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens a dish to change what it is, how much, or remove it.
  Future<void> _editItem(int i) async {
    final byId = ref.read(allFoodsByIdProvider);
    final alternatives = [
      for (final g in _guesses)
        if (g.food != null) g.food!,
      for (final id in _commonDishes) ?byId[id],
    ].fold(<Food>[], (List<Food> l, f) => l.any((x) => x.id == f.id) ? l : [...l, f]).take(10).toList();
    final r = await SheetFrame.show<DishEdit>(context, DishEditSheet(item: _items[i], alternatives: alternatives));
    if (r == null || !mounted) return;
    setState(() {
      if (r.item == null) {
        _items.removeAt(i);
      } else {
        _items[i] = r.item!;
      }
    });
  }

  /// Adds a dish the camera didn't find.
  Future<void> _addMissing() async {
    final f = await pickDish(context);
    if (f == null || !mounted) return;
    setState(() => _items = [..._items, ScannedItem.fromFood(f, 1)]);
  }

  Future<void> _manual({String? query}) async {
    final added = await SheetFrame.show<MealEntry>(context, FoodSearchSheet(meal: _meal, initialQuery: query));
    if (added != null && mounted && _items.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(foodClassifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [Text(tr('Scan food')), SizedBox(width: 10), BetaTag()]),
        actions: [
          if (_phase == _Phase.result)
            TextButton.icon(onPressed: _retake, icon: const Icon(Icons.refresh_rounded), label: Text(tr('Retake'))),
        ],
      ),
      body: PageBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          child: switch ((model, _phase)) {
            (AsyncLoading(), _) => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
            (AsyncData(value: null) || AsyncError(), _) => _NotConfigured(
              key: const ValueKey('setup'),
              onManual: () => _manual(),
            ),
            (_, _Phase.pick) => _pickView(context),
            (_, _Phase.scanning) => _Scanning(key: const ValueKey('scanning'), image: _image!.bytes),
            (_, _Phase.result) => _resultView(context),
          },
        ),
      ),
    );
  }

  Widget _mealPills() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final m in MealType.values)
        ChoicePill(label: m.label, selected: _meal == m, onTap: () => setState(() => _meal = m)),
    ],
  );

  Widget _pickView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('pick'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const BetaNote(),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)),
                child: Icon(Icons.photo_camera_outlined, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(tr('Photograph your food'), style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                tr(
                  'Shoot from above in good light with the whole plate in frame. '
                  'Recognition happens on your phone — the photo is never uploaded.',
                ),
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: tr('Take photo'),
                icon: Icons.photo_camera_rounded,
                onPressed: () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(tr('Choose from gallery')),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          GlassCard(
            glow: AppColors.danger,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.danger),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: text.bodyMedium)),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        ],
        FormSection(title: tr('Add to'), child: _mealPills()),
        const SizedBox(height: 18),
        Center(
          child: TextButton(onPressed: () => _manual(), child: Text(tr('Search and add manually instead'))),
        ),
      ],
    );
  }

  Widget _resultView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final diet = ref.watch(profileProvider)?.diet;
    final offDiet = diet == null ? const <ScannedItem>[] : _items.where((i) => !i.cls.fits(diet)).toList();
    return Column(
      key: const ValueKey('result'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              // The plate, with each dish marked (tap a tag to edit it).
              PlatePhoto(image: _image!.bytes, items: _items, onTapItem: _editItem),
              const SizedBox(height: 14),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    tr("Couldn't recognise this plate. Tap the dishes you see below."),
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              NutritionTable(items: _items, onEdit: _editItem, onAdd: _addMissing),
              const SizedBox(height: 12),
              _quickAdd(text),
              if (offDiet.isNotEmpty)
                _Notice(
                  icon: Icons.eco_outlined,
                  text: '${offDiet.map((e) => e.name).join(', ')} may not fit your diet. Remove it if that\'s wrong.',
                ),
              const _Notice(
                icon: Icons.straighten_rounded,
                text:
                    'Check the portion: set how many servings you ate with − and +. A photo can\'t measure '
                    'amounts exactly.',
              ),
              const _Notice(
                icon: Icons.lock_outline_rounded,
                text: 'Recognised on your phone. The photo stays on this phone only.',
              ),
              if (_items.isNotEmpty) FormSection(title: tr('Add to'), child: _mealPills()),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _items.isEmpty
                ? GradientButton(label: tr('Try another photo'), icon: Icons.refresh_rounded, onPressed: _retake)
                : GradientButton(
                    label: 'Add to ${_meal.label.toLowerCase()}',
                    icon: Icons.check_rounded,
                    onPressed: _log,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Scanning extends StatelessWidget {
  const _Scanning({super.key, required this.image});

  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Image.memory(image, width: 240, height: 240, fit: BoxFit.cover),
                  // A soft band that sweeps down the photo while it's analysed.
                  Positioned.fill(
                    child:
                        DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.45),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .moveY(begin: -240, end: 240, duration: 1600.ms, curve: Curves.easeInOut),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(tr('Recognising your food…'), style: text.titleMedium),
            const SizedBox(height: 4),
            Text(tr('On your phone — nothing is uploaded'), style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.item});

  final ScannedItem item;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _fields = {
    'kcal': TextEditingController(text: widget.item.macros.kcal.round().toString()),
    'protein': TextEditingController(text: _fmt(widget.item.macros.protein)),
    'carbs': TextEditingController(text: _fmt(widget.item.macros.carbs)),
    'fat': TextEditingController(text: _fmt(widget.item.macros.fat)),
    'fiber': TextEditingController(text: _fmt(widget.item.macros.fiber)),
  };

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    _name.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(String k) => double.tryParse(_fields[k]!.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    Widget num(String k, String label, String suffix) => Expanded(
      child: TextField(
        controller: _fields[k],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );
    return SheetFrame(
      title: tr('Edit item'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          children: [
            Text(
              'Values for ${widget.item.portion.isEmpty ? 'the portion in the photo' : widget.item.portion}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: tr('Name')),
            ),
            const SizedBox(height: 12),
            Row(children: [num('kcal', 'Calories', 'kcal'), const SizedBox(width: 10), num('protein', 'Protein', 'g')]),
            const SizedBox(height: 12),
            Row(
              children: [
                num('carbs', 'Carbs', 'g'),
                const SizedBox(width: 10),
                num('fat', 'Fat', 'g'),
                const SizedBox(width: 10),
                num('fiber', 'Fiber', 'g'),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: tr('Save'),
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(
                context,
                widget.item.copyWith(
                  name: _name.text.trim().isEmpty ? widget.item.name : _name.text.trim(),
                  macros: Macros(
                    kcal: _v('kcal'),
                    protein: _v('protein'),
                    carbs: _v('carbs'),
                    fat: _v('fat'),
                    fiber: _v('fiber'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({super.key, required this.onManual});

  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)),
                child: Icon(Icons.no_photography_outlined, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(tr('Food recognition unavailable'), style: text.titleLarge),
              const SizedBox(height: 8),
              Text(
                "This version of the app doesn't include the food-recognition model. "
                'You can still search and add foods.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GradientButton(label: tr('Add food manually'), icon: Icons.search_rounded, onPressed: onManual),
            ],
          ),
        ),
      ],
    );
  }
}
