import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../diet/diet_providers.dart';
import '../diet/domain/food.dart';
import '../diet/domain/meal_log.dart';
import '../diet/widgets/food_search_sheet.dart';
import '../diet/widgets/sheet_frame.dart';
import '../profile/profile_providers.dart';
import 'domain/scan_result.dart';
import 'food_scanner.dart';

typedef PickedImage = ({Uint8List bytes, String mediaType});

/// Opens the camera or gallery and returns a downscaled JPEG. Overridden in tests.
final pickImageProvider = Provider<Future<PickedImage?> Function(ImageSource)>(
  (ref) => (source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    if (x == null) return null;
    final type = x.mimeType ?? (x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return (bytes: await x.readAsBytes(), mediaType: type);
  },
);

enum _Phase { pick, scanning, result }

/// Phase 6: photograph a plate, get an editable estimate of each item's
/// calories, protein, carbs, fat and fiber, then log it to a meal.
class ScanFoodScreen extends ConsumerStatefulWidget {
  const ScanFoodScreen({super.key, this.meal = MealType.lunch});

  final MealType meal;

  @override
  ConsumerState<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends ConsumerState<ScanFoodScreen> {
  late MealType _meal = widget.meal;
  final _hint = TextEditingController();
  _Phase _phase = _Phase.pick;
  PickedImage? _image;
  ScanResult? _result;
  List<ScannedItem> _items = [];
  String? _error;

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final scanner = ref.read(foodScannerProvider);
    if (scanner == null) return;
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
      final r = await scanner.scan(img.bytes, img.mediaType, hint: _hint.text);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _result = r;
        _items = [...r.items];
        _phase = _Phase.result;
      });
    } on ScanFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _Phase.pick;
      });
    }
  }

  void _retake() => setState(() {
    _phase = _Phase.pick;
    _result = null;
    _items = [];
  });

  Future<void> _log() async {
    final base = MealLogNotifier.newId();
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
        ),
    ]);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${_items.length} ${_items.length == 1 ? 'item' : 'items'} to ${_meal.label.toLowerCase()}',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _manual() async {
    final added = await SheetFrame.show<MealEntry>(context, FoodSearchSheet(meal: _meal));
    if (added != null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(foodScannerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan food'),
        actions: [
          if (_phase == _Phase.result)
            TextButton.icon(onPressed: _retake, icon: const Icon(Icons.refresh_rounded), label: const Text('Retake')),
        ],
      ),
      body: PageBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          child: switch ((scanner, _phase)) {
            (null, _) => _NotConfigured(key: const ValueKey('setup'), onManual: _manual),
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
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.photo_camera_outlined, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text('Photograph your plate', style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Shoot from above in good light with the whole plate in view. You can adjust every value before saving.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Take photo',
                icon: Icons.photo_camera_rounded,
                onPressed: () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
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
        FormSection(
          title: 'What is it? (optional)',
          child: TextField(
            controller: _hint,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. homemade rajma chawal, less oil'),
          ),
        ),
        FormSection(title: 'Add to', child: _mealPills()),
        const SizedBox(height: 18),
        Center(
          child: TextButton(onPressed: _manual, child: const Text('Search and add manually instead')),
        ),
      ],
    );
  }

  Widget _resultView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = _result!;
    final total = _items.fold(const Macros(), (m, i) => m + i.scaled);
    final diet = ref.watch(profileProvider)?.diet;
    final offDiet = diet == null ? const <ScannedItem>[] : _items.where((i) => !i.cls.fits(diet)).toList();
    return Column(
      key: const ValueKey('result'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_image!.bytes, width: 84, height: 84, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.isFood ? '${total.kcal.round()} kcal' : 'No food found', style: text.headlineSmall),
                        Text(
                          r.isFood
                              ? '${total.protein.round()} g protein · ${total.carbs.round()} g carbs · '
                                    '${total.fiber.round()} g fiber'
                              : 'Try another photo, closer and in better light.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final (i, item) in _items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItemCard(
                    item: item,
                    onFactor: (f) => setState(() => _items[i] = item.copyWith(factor: f)),
                    onEdit: () async {
                      final edited = await SheetFrame.show<ScannedItem>(context, _EditItemSheet(item: item));
                      if (edited != null) setState(() => _items[i] = edited);
                    },
                    onRemove: () => setState(() => _items.removeAt(i)),
                  ).animate(delay: (i * 50).ms).fadeIn(duration: 250.ms).moveY(begin: 6, end: 0),
                ),
              if (offDiet.isNotEmpty)
                _Notice(
                  icon: Icons.eco_outlined,
                  text: '${offDiet.map((e) => e.name).join(', ')} may not fit your diet. Remove it if that\'s wrong.',
                ),
              if (r.note.isNotEmpty) _Notice(icon: Icons.lightbulb_outline_rounded, text: r.note),
              const _Notice(
                icon: Icons.info_outline_rounded,
                text: 'Estimates from a photo. Hidden oil, sugar and portion depth can change the real numbers.',
              ),
              if (_items.isNotEmpty) FormSection(title: 'Add to', child: _mealPills()),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _items.isEmpty
                ? GradientButton(label: 'Try another photo', icon: Icons.refresh_rounded, onPressed: _retake)
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
            Text('Reading your plate…', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Usually takes a few seconds', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onFactor, required this.onEdit, required this.onRemove});

  final ScannedItem item;
  final ValueChanged<double> onFactor;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = item.scaled;
    final f = item.factor;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: text.titleSmall),
                    Text(
                      [if (item.portion.isNotEmpty) item.portion, if (item.grams > 0) '~${item.grams} g'].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (item.confidence == ScanConfidence.low)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                  child: Text('Unsure', style: text.labelSmall?.copyWith(color: AppColors.amber)),
                ),
              IconButton(
                tooltip: 'Edit ${item.name}',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Remove ${item.name}',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.kcal.round()} kcal', style: text.titleMedium),
                    Text(
                      'P ${m.protein.round()} g · C ${m.carbs.round()} g · F ${m.fat.round()} g · '
                      'Fiber ${m.fiber.round()} g',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              _MiniStepper(value: f, onChanged: onFactor),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// Portion multiplier: ½× … 3×.
class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, double next, bool on) => Pressable(
      onTap: on
          ? () {
              HapticFeedback.selectionClick();
              onChanged(next);
            }
          : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: on ? AppColors.primary : AppColors.textMuted),
      ),
    );
    final label = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return Row(
      children: [
        btn(Icons.remove_rounded, value - 0.5, value > 0.5),
        SizedBox(
          width: 38,
          child: Text('$label×', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
        ),
        btn(Icons.add_rounded, value + 0.5, value < 3),
      ],
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
      title: 'Edit item',
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
              decoration: const InputDecoration(labelText: 'Name'),
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
              label: 'Save',
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
                child: const Icon(Icons.cloud_off_outlined, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text('Scanner not connected', style: text.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Food scanning runs on a secure server so no API keys are stored in the app. '
                'This build is in demo mode, so the scanner is off.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'To turn it on: connect the app to Firebase, then deploy backend/functions with an '
                'ANTHROPIC_API_KEY secret (see backend/README.md).',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GradientButton(label: 'Add food manually', icon: Icons.search_rounded, onPressed: onManual),
            ],
          ),
        ),
      ],
    );
  }
}
