import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/pressable.dart';
import '../alarm/alarm_providers.dart';
import '../profile/domain/health_targets.dart';
import '../profile/domain/user_profile.dart';
import '../profile/profile_providers.dart';
import 'widgets/choice_card.dart';
import 'widgets/ruler_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _nameController = TextEditingController();
  int _page = 0;

  // Draft answers.
  Gender? _gender;
  double _age = 22;
  double _height = 170;
  double _weight = 65;
  FitnessGoal? _goal;
  ActivityLevel? _activity;
  DietType? _diet;
  FitnessLevel? _level;
  TimeOfDay _wake = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _sleep = const TimeOfDay(hour: 22, minute: 30);

  static const _stepCount = 11;

  @override
  void dispose() {
    _pages.dispose();
    _nameController.dispose();
    super.dispose();
  }

  UserProfile get _draft => UserProfile(
    name: _nameController.text.trim(),
    gender: _gender ?? Gender.other,
    age: _age.round(),
    heightCm: _height,
    weightKg: _weight,
    goal: _goal ?? FitnessGoal.maintain,
    activity: _activity ?? ActivityLevel.light,
    diet: _diet ?? DietType.veg,
    level: _level ?? FitnessLevel.beginner,
    wakeTime: _wake,
    sleepTime: _sleep,
  );

  bool get _canContinue => switch (_page) {
    1 => _nameController.text.trim().isNotEmpty,
    2 => _gender != null,
    5 => _goal != null,
    6 => _activity != null,
    7 => _diet != null,
    8 => _level != null,
    _ => true,
  };

  void _go(int delta) {
    FocusScope.of(context).unfocus();
    final next = (_page + delta).clamp(0, _stepCount - 1);
    _pages.animateToPage(next, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
    setState(() => _page = next);
  }

  Future<void> _finish() async {
    HapticFeedback.heavyImpact();
    // Create the first alarm before the profile, since saving the profile
    // navigates away from onboarding.
    await ref.read(alarmsProvider.notifier).createDefault(_draft);
    await ref.read(profileProvider.notifier).save(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _stepCount - 1;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _page == 0 ? const SizedBox(height: 56) : _topBar(),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _welcome(),
                    _nameStep(),
                    _aboutStep(),
                    _heightStep(),
                    _weightStep(),
                    _goalStep(),
                    _activityStep(),
                    _dietStep(),
                    _levelStep(),
                    _timesStep(),
                    _summaryStep(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: GradientButton(
                  label: switch (_page) {
                    0 => 'Get started',
                    9 => 'Build my plan',
                    _ when last => "Let's go",
                    _ => 'Continue',
                  },
                  icon: last ? Icons.bolt_rounded : Icons.arrow_forward_rounded,
                  onPressed: !_canContinue ? null : (last ? _finish : () => _go(1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      key: const ValueKey('top'),
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
      child: Row(
        children: [
          IconButton(onPressed: () => _go(-1), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i < _stepCount; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: i <= _page ? AppColors.brandGradient : null,
                        color: i <= _page ? null : AppColors.surfaceHigh,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- steps

  Widget _step({required String title, String? subtitle, required Widget child, bool scroll = true}) {
    final text = Theme.of(context).textTheme;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: text.headlineMedium).animate().fadeIn(duration: 400.ms).slideX(begin: 0.08),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: text.bodyMedium).animate(delay: 80.ms).fadeIn(duration: 400.ms),
        ],
        const SizedBox(height: 28),
        child.animate(delay: 150.ms).fadeIn(duration: 450.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: scroll ? SingleChildScrollView(physics: const BouncingScrollPhysics(), child: body) : body,
    );
  }

  Widget _welcome() {
    final text = Theme.of(context).textTheme;
    const features = [
      (
        Icons.alarm_on_rounded,
        AppColors.workout,
        'Alarm that needs your reps',
        'Camera counts your squats before it stops ringing',
      ),
      (
        Icons.view_timeline_rounded,
        AppColors.accent,
        'Your whole day, planned',
        'Meals, work, water & workouts — on time',
      ),
      (Icons.directions_walk_rounded, AppColors.steps, 'Verified steps', 'Sensor + GPS, with bike & car rides removed'),
      (
        Icons.local_fire_department_rounded,
        AppColors.protein,
        'Streaks that glow',
        'Every perfect day lights up your grid',
      ),
    ];
    // Scrolls on short screens, centres vertically on tall ones.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(child: _welcomeContent(features, text)),
        ),
      ),
    );
  }

  Widget _welcomeContent(List<(IconData, Color, String, String)> features, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const AppLogo(size: 64).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 28),
        Text(
          'Your mornings\nare about to change.',
          style: text.displaySmall?.copyWith(height: 1.15),
        ).animate(delay: 150.ms).fadeIn(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic),
        const SizedBox(height: 12),
        Text(
          '${AppInfo.name} turns your alarm into a workout coach — and your day into a routine you actually keep.',
          style: text.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.5),
        ).animate(delay: 300.ms).fadeIn(duration: 600.ms),
        const SizedBox(height: 32),
        for (final (i, f) in features.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: f.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(f.$1, color: f.$2, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$3, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(f.$4, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ).animate(delay: (450 + i * 110).ms).fadeIn(duration: 500.ms).slideX(begin: 0.1),
          ),
        const Spacer(),
      ],
    );
  }

  Widget _nameStep() => _step(
    title: "What should we\ncall you?",
    subtitle: "We'll use it to cheer you on.",
    child: TextField(
      controller: _nameController,
      autofocus: false,
      textCapitalization: TextCapitalization.words,
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: const InputDecoration(hintText: 'Your name'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _canContinue ? _go(1) : null,
    ),
  );

  Widget _aboutStep() => _step(
    title: 'Tell us about you',
    subtitle: 'This makes your calorie and protein targets accurate.',
    child: Column(
      children: [
        Row(
          children: [
            for (final (g, label, emoji) in [
              (Gender.male, 'Male', '👨'),
              (Gender.female, 'Female', '👩'),
              (Gender.other, 'Other', '🧑'),
            ]) ...[
              Expanded(
                child: SizedBox(
                  height: 132,
                  child: ChoiceCard(
                    compact: true,
                    title: label,
                    emoji: emoji,
                    selected: _gender == g,
                    onTap: () => setState(() => _gender = g),
                  ),
                ),
              ),
              if (g != Gender.other) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 36),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Age', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        RulerPicker(min: 13, max: 90, value: _age, unit: 'years', onChanged: (v) => setState(() => _age = v)),
      ],
    ),
  );

  Widget _heightStep() => _step(
    title: 'How tall are you?',
    subtitle: 'Also used to measure your stride for GPS steps.',
    child: Padding(
      padding: const EdgeInsets.only(top: 40),
      child: RulerPicker(
        min: 120,
        max: 220,
        value: _height,
        unit: 'cm',
        color: AppColors.accent,
        onChanged: (v) => setState(() => _height = v),
      ),
    ),
  );

  Widget _weightStep() => _step(
    title: "What's your weight?",
    subtitle: 'Only you can see this.',
    child: Padding(
      padding: const EdgeInsets.only(top: 40),
      child: RulerPicker(
        min: 30,
        max: 180,
        step: 0.5,
        decimals: 1,
        value: _weight,
        unit: 'kg',
        color: AppColors.water,
        onChanged: (v) => setState(() => _weight = v),
      ),
    ),
  );

  Widget _options<T>(List<(T, String, String, IconData, Color)> items, T? selected, ValueChanged<T> onPick) => Column(
    children: [
      for (final (i, o) in items.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChoiceCard(
            title: o.$2,
            subtitle: o.$3,
            icon: o.$4,
            color: o.$5,
            selected: selected == o.$1,
            onTap: () => onPick(o.$1),
          ).animate(delay: (i * 60).ms).fadeIn(duration: 350.ms).slideY(begin: 0.15),
        ),
    ],
  );

  Widget _goalStep() => _step(
    title: "What's your main goal?",
    child: _options(
      const [
        (
          FitnessGoal.loseWeight,
          'Lose weight',
          'Burn fat with a gentle calorie deficit',
          Icons.trending_down_rounded,
          AppColors.steps,
        ),
        (
          FitnessGoal.maintain,
          'Stay fit',
          'Keep your weight, build healthy habits',
          Icons.favorite_rounded,
          AppColors.accent,
        ),
        (
          FitnessGoal.buildMuscle,
          'Build muscle',
          'High protein and a small surplus',
          Icons.fitness_center_rounded,
          AppColors.primary,
        ),
      ],
      _goal,
      (v) => setState(() => _goal = v),
    ),
  );

  Widget _activityStep() => _step(
    title: 'How active is your day?',
    subtitle: 'Outside of planned workouts.',
    child: _options(
      const [
        (
          ActivityLevel.sedentary,
          'Mostly sitting',
          'Desk work, little walking',
          Icons.chair_rounded,
          AppColors.textSecondary,
        ),
        (
          ActivityLevel.light,
          'Lightly active',
          'Some walking, light exercise 1–3×/week',
          Icons.directions_walk_rounded,
          AppColors.water,
        ),
        (
          ActivityLevel.moderate,
          'Moderately active',
          'On your feet, exercise 3–5×/week',
          Icons.directions_run_rounded,
          AppColors.accent,
        ),
        (
          ActivityLevel.active,
          'Very active',
          'Hard exercise 6–7×/week',
          Icons.sports_gymnastics_rounded,
          AppColors.primary,
        ),
        (
          ActivityLevel.veryActive,
          'Athlete',
          'Physical job or training twice a day',
          Icons.emoji_events_rounded,
          AppColors.steps,
        ),
      ],
      _activity,
      (v) => setState(() => _activity = v),
    ),
  );

  Widget _dietStep() {
    const items = [
      (DietType.veg, 'Vegetarian', 'Paneer, dal, curd', '🥗'),
      (DietType.nonVeg, 'Non-veg', 'Chicken, fish, eggs', '🍗'),
      (DietType.eggetarian, 'Eggetarian', 'Veg + eggs', '🥚'),
      (DietType.vegan, 'Vegan', 'No animal products', '🌱'),
    ];
    return _step(
      title: 'How do you eat?',
      subtitle: 'Your meal plan and protein sources will match this.',
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 164,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (i, d) in items.indexed)
            ChoiceCard(
              compact: true,
              title: d.$2,
              subtitle: d.$3,
              emoji: d.$4,
              color: AppColors.diet,
              selected: _diet == d.$1,
              onTap: () => setState(() => _diet = d.$1),
            ).animate(delay: (i * 70).ms).fadeIn(duration: 350.ms).scale(begin: const Offset(0.92, 0.92)),
        ],
      ),
    );
  }

  Widget _levelStep() => _step(
    title: 'Your fitness level?',
    subtitle: 'Sets the difficulty of your alarm routine. You can change it anytime.',
    child: _options(
      const [
        (
          FitnessLevel.beginner,
          'Beginner',
          '10 squats · 10 jumping jacks · 20s plank',
          Icons.looks_one_rounded,
          AppColors.accent,
        ),
        (
          FitnessLevel.moderate,
          'Moderate',
          '20 squats · 15 push-ups · 20 lunges',
          Icons.looks_two_rounded,
          AppColors.primary,
        ),
        (
          FitnessLevel.advanced,
          'Advanced',
          '30 squats · 25 push-ups · 60s plank',
          Icons.looks_3_rounded,
          AppColors.steps,
        ),
      ],
      _level,
      (v) => setState(() => _level = v),
    ),
  );

  Widget _timesStep() {
    Future<void> pick(bool wake) async {
      final picked = await showTimePicker(context: context, initialTime: wake ? _wake : _sleep);
      if (picked != null) setState(() => wake ? _wake = picked : _sleep = picked);
    }

    Widget card(bool wake) {
      final t = wake ? _wake : _sleep;
      final color = wake ? AppColors.primary : AppColors.diet;
      final text = Theme.of(context).textTheme;
      return Pressable(
        onTap: () => pick(wake),
        child: GlassCard(
          glow: color,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(wake ? Icons.wb_sunny_rounded : Icons.nightlight_round, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wake ? 'Wake up' : 'Sleep', style: text.bodyMedium),
                    Text(t.format(context), style: text.headlineMedium),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      );
    }

    return _step(
      title: 'When does your\nday start?',
      subtitle: 'Your first workout alarm will be set for your wake-up time. Reminders stay quiet while you sleep.',
      child: Column(children: [card(true), const SizedBox(height: 14), card(false)]),
    );
  }

  Widget _summaryStep() {
    if (_page != _stepCount - 1) return const SizedBox.shrink();
    final t = HealthTargets.from(_draft);
    final text = Theme.of(context).textTheme;

    Widget tile(String label, num value, String unit, Color color, IconData icon, int i) => GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedNumber(value, suffix: unit, decimals: value is double ? 1 : 0, style: text.headlineSmall),
          ),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    ).animate(delay: (300 + i * 90).ms).fadeIn(duration: 450.ms).scale(begin: const Offset(0.9, 0.9));

    return _step(
      title: 'Your plan is ready,\n${_draft.name.split(' ').first} 🎉',
      subtitle: 'Built from your body, goal and lifestyle. Adjust it anytime.',
      child: Column(
        children: [
          GlassCard(
            glow: AppColors.primary,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily calories', style: text.bodyMedium),
                      AnimatedNumber(
                        t.calories,
                        suffix: ' kcal',
                        style: text.displaySmall?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text('Maintenance ${t.tdee} kcal · BMI ${t.bmi}', style: text.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 44),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 500.ms),
          const SizedBox(height: 12),
          GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 124,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              tile('Protein', t.proteinG, ' g', AppColors.protein, Icons.egg_alt_rounded, 0),
              tile('Carbs', t.carbsG, ' g', AppColors.steps, Icons.bakery_dining_rounded, 1),
              tile('Fat', t.fatG, ' g', AppColors.diet, Icons.water_drop_outlined, 2),
              tile('Fiber', t.fiberG, ' g', AppColors.accent, Icons.grass_rounded, 3),
              tile('Water', t.waterMl / 1000, ' L', AppColors.water, Icons.water_drop_rounded, 4),
              tile('Steps', t.steps, '', AppColors.primary, Icons.directions_walk_rounded, 5),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
