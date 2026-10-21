import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/pressable.dart';
import 'domain/exercise.dart';
import 'domain/routine.dart';
import 'routine_providers.dart';

/// Create or edit a custom routine: any exercises, any reps.
class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.routine});

  final Routine? routine;

  @override
  ConsumerState<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  late final _name = TextEditingController(text: widget.routine?.name ?? 'My routine');
  late List<RoutineStep> _steps = [
    ...?widget.routine?.steps,
    if (widget.routine == null) const RoutineStep(Exercise.squat, 15),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _change(int i, int delta) {
    HapticFeedback.selectionClick();
    final s = _steps[i];
    final step = s.exercise.timed ? 5 : 1;
    final next = (s.target + delta * step).clamp(step, s.exercise.timed ? 300 : 200);
    setState(() => _steps = [..._steps]..[i] = RoutineStep(s.exercise, next));
  }

  Future<void> _addStep() async {
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => const _ExercisePicker(),
    );
    if (picked != null) setState(() => _steps = [..._steps, RoutineStep(picked, picked.defaultTarget)]);
  }

  Future<void> _save() async {
    final id = widget.routine?.id ?? 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final name = _name.text.trim().isEmpty ? 'My routine' : _name.text.trim();
    await ref.read(routinesProvider.notifier).save(Routine(id: id, name: name, steps: _steps));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'New routine' : 'Edit routine'),
        actions: [
          if (widget.routine != null)
            IconButton(
              onPressed: () async {
                await ref.read(routinesProvider.notifier).delete(widget.routine!.id);
                if (context.mounted) context.pop();
              },
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                header: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add exercise'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                onReorderItem: (from, to) => setState(() {
                  final list = [..._steps];
                  list.insert(to, list.removeAt(from));
                  _steps = list;
                }),
                children: [
                  for (final (i, s) in _steps.indexed)
                    Padding(
                      key: ValueKey('$i-${s.exercise.name}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        child: Row(
                          children: [
                            Icon(s.exercise.icon, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.exercise.label, style: text.titleMedium),
                                  Text(s.exercise.muscles, style: text.bodySmall),
                                ],
                              ),
                            ),
                            _Round(icon: Icons.remove_rounded, onTap: () => _change(i, -1)),
                            SizedBox(
                              width: 52,
                              child: Text(
                                s.exercise.formatTarget(s.target),
                                textAlign: TextAlign.center,
                                style: text.titleMedium,
                              ),
                            ),
                            _Round(icon: Icons.add_rounded, onTap: () => _change(i, 1)),
                            IconButton(
                              onPressed: _steps.length == 1
                                  ? null
                                  : () => setState(() => _steps = [..._steps]..removeAt(i)),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: GradientButton(label: 'Save routine', onPressed: _steps.isEmpty ? null : _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.85,
    child: Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: AppColors.textPrimary),
    ),
  );
}

/// All exercises, grouped by body area.
class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (c, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 2),
            child: Text('Add exercise', style: text.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text('Every exercise is counted by the camera.', style: text.bodySmall),
          ),
          for (final g in ExerciseGroup.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
              child: Text(
                g.label.toUpperCase(),
                style: text.labelSmall?.copyWith(letterSpacing: 1.2, color: AppColors.textMuted),
              ),
            ),
            for (final e in Exercise.values.where((e) => e.group == g))
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(e.icon, color: AppColors.primary, size: 20),
                ),
                title: Text(e.label, style: text.titleSmall),
                subtitle: Text('${e.muscles} · ${e.timed ? 'timed hold' : 'reps'}', style: text.bodySmall),
                trailing: const Icon(Icons.add_rounded, color: AppColors.primary),
                onTap: () => Navigator.pop(context, e),
              ),
          ],
        ],
      ),
    );
  }
}
