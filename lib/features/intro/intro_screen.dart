import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';

/// Whether the feature tour has been shown. People who used FittArc before
/// it existed skip it.
class IntroSeenNotifier extends Notifier<bool> {
  static const key = 'intro.seen.v1';

  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    return prefs.getBool(key) ?? prefs.containsKey('profile.v1');
  }

  Future<void> done() async {
    state = true;
    await ref.read(sharedPrefsProvider).setBool(key, true);
  }
}

final introSeenProvider = NotifierProvider<IntroSeenNotifier, bool>(IntroSeenNotifier.new);

/// What FittArc can do, in a few swipes, before sign-in.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _pages = PageController();
  int _page = 0;

  static const slides = [
    (
      '🏆',
      'Fitness that feels like a game',
      'Seasonal Arcs, XP, levels, badges and streaks. Every goal you hit moves you up.',
      [
        'Winter, Summer, Thunder and more Arcs, each with its own look',
        'Festival themes like Diwali, Eid and Christmas',
      ],
    ),
    (
      '⏰',
      'Wake up moving',
      'Alarms that ring until you do a quick workout or brain game. The camera counts your reps.',
      ['Workouts for every level, at home, no gym', 'Body map shows which muscles each move works'],
    ),
    (
      '🏃',
      'Run, walk, cycle, skip',
      'Track your route on the map with accurate GPS: distance, pace, time and calories.',
      ['Steps counted all day', 'Rope skipping counted by your phone'],
    ),
    (
      '📸',
      'Snap your food',
      'Take a photo of your plate: FittArc finds each dish and shows calories, protein, carbs and fibre.',
      ['Edit any dish in one tap', 'Water and meal reminders'],
    ),
    (
      '❤️',
      'Health and your watch',
      'Heart rate with your camera, height, weight, BMI and a body check. Connect your smartwatch too.',
      ['Sleep alarm and sleep mode', 'Approximate wellness estimates, not medical tests'],
    ),
    (
      '👥',
      'Better together',
      'Add friends, join clubs near you, run club challenges and keep team streaks alive.',
      ['Rankings, chat and food snaps that disappear in 24 hours', 'Nudges when friends finish their goals'],
    ),
    (
      '📊',
      'See your progress',
      'A daily report every evening, Arc Wrapped each season, and cards to share on Instagram and WhatsApp.',
      ['Your progress is backed up to your account', 'Works in English, ಕನ್ನಡ and हिन्दी'],
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == slides.length - 1) {
      ref.read(introSeenProvider.notifier).done();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _page == slides.length - 1;
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref.read(introSeenProvider.notifier).done(),
                  child: Text(tr('Skip')),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final (emoji, title, body, points) in slides)
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Container(
                              width: 132,
                              height: 132,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primarySoft),
                              child: Text(emoji, style: const TextStyle(fontSize: 64)),
                            ),
                            const SizedBox(height: 28),
                            Text(tr(title), textAlign: TextAlign.center, style: text.headlineSmall),
                            const SizedBox(height: 12),
                            Text(tr(body), textAlign: TextAlign.center, style: text.bodyLarge),
                            const SizedBox(height: 20),
                            for (final p in points)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(tr(p), style: text.bodyMedium)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.primary : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                child: GradientButton(
                  label: last ? tr('Get started') : tr('Next'),
                  icon: last ? Icons.bolt_rounded : Icons.arrow_forward_rounded,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
