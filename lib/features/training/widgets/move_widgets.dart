import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../diet/widgets/sheet_frame.dart';
import '../../workout/widgets/exercise_demo.dart';
import '../domain/move.dart';
import '../domain/plans.dart';

/// Animated stick figure for [move] on a soft cream tile.
class MoveThumb extends StatelessWidget {
  const MoveThumb({super.key, required this.move, this.size = 60});

  final Move move;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
    child: ExerciseDemo.move(demoId: move.demo, label: move.name, height: size - 8),
  );
}

/// A move in a list: animation, name, target and a how-to hint.
class MoveRow extends StatelessWidget {
  const MoveRow({super.key, required this.move, this.target, this.onTap});

  final Move move;

  /// "×12" or "30s"; muscles are shown when null.
  final String? target;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      scale: 0.98,
      onTap: onTap ?? () => showMoveHowTo(context, move),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            MoveThumb(move: move),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(move.name, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    target ?? move.muscles,
                    style: text.bodySmall?.copyWith(
                      color: target == null ? AppColors.textSecondary : AppColors.primary,
                      fontWeight: target == null ? null : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.help_outline_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: large animation, muscles, equipment and step-by-step how-to.
Future<void> showMoveHowTo(BuildContext context, Move move, {WorkoutItem? item}) {
  final text = Theme.of(context).textTheme;
  return SheetFrame.show<void>(
    context,
    SheetFrame(
      title: move.name,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(icon: Icons.fitness_center_rounded, label: move.muscles),
                if (item != null) _Chip(icon: Icons.flag_rounded, label: item.label),
                if (move.equipment != null) _Chip(icon: Icons.handyman_rounded, label: move.equipment!),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
              child: ExerciseDemo.move(demoId: move.demo, label: move.name, height: 190),
            ),
            const SizedBox(height: 16),
            Text('How to do it', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final (i, step) in move.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: text.labelMedium?.copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step, style: text.bodyMedium?.copyWith(height: 1.45))),
                  ],
                ),
              ),
            if (move.perSide)
              Text(
                'Do both sides: the target is for each side.',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.amber)),
        ),
      ],
    ),
  );
}

/// Espresso hero card with a white animated figure on the right.
class HeroWorkoutCard extends StatelessWidget {
  const HeroWorkoutCard({
    super.key,
    required this.demo,
    required this.title,
    required this.child,
    this.onTap,
    this.eyebrow,
  });

  final String demo;
  final String title;
  final String? eyebrow;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.inkSoft, AppColors.ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.softShadow(AppColors.ink),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: text.labelSmall?.copyWith(color: AppColors.energyLight, letterSpacing: 1.2),
                  ),
                if (eyebrow != null) const SizedBox(height: 4),
                Text(title, style: text.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white70),
                  child: child,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 104,
            child: ExerciseDemo.move(demoId: demo, label: title, height: 96, dark: true),
          ),
        ],
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

/// Thin caramel progress bar for dark cards.
class EnergyBar extends StatelessWidget {
  const EnergyBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Stack(
      children: [
        Container(height: 6, color: Colors.white12),
        FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          child: Container(height: 6, decoration: const BoxDecoration(gradient: AppColors.energyGradient)),
        ),
      ],
    ),
  );
}
