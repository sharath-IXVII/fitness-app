import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/beta_tag.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import 'domain/live_hr.dart';
import 'health_providers.dart';
import 'watch_data.dart';

/// What Health Connect says right now. Read again when the page opens or the
/// person comes back from the permission screen.
class _WatchState {
  const _WatchState(this.status, [this.snapshot]);

  final WatchStatus status;
  final WatchSnapshot? snapshot;
}

final _watchStateProvider = FutureProvider.autoDispose<_WatchState>((ref) async {
  final source = ref.watch(watchDataProvider);
  try {
    final status = await source.status();
    if (status != WatchStatus.ready) return _WatchState(status);
    return _WatchState(status, await source.read(clock.now()));
  } catch (_) {
    return const _WatchState(WatchStatus.unavailable);
  }
});

/// Connect a watch: live heart rate over Bluetooth, and steps, heart rate and
/// sleep from Health Connect.
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final week = ref.watch(weekArcProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Watch'), SizedBox(width: 10), BetaTag()]),
      ),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ProgressRing(
                    progress: week / weeklyArcGoal,
                    color: AppColors.primary,
                    size: 78,
                    stroke: 9,
                    child: Text(week.toStringAsFixed(0), style: text.titleMedium),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Arc minutes this week', style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '$weeklyArcGoal is the weekly goal. A moderate minute counts once and a hard minute counts '
                          'twice, so a short hard workout fills the ring faster.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Pressable(
              onTap: () => context.push(Routes.liveHeart),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.bluetooth_searching_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live heart rate', style: text.titleMedium),
                          Text(
                            'Connect a watch or chest strap by Bluetooth and earn Arc minutes as you train.',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _HealthConnectCard(),
            const SizedBox(height: 14),
            Text(
              'Reminders and alarms already show on a paired watch, because the watch mirrors your phone\'s '
              'notifications. Heart rate and steps from a watch are not medical measurements.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthConnectCard extends ConsumerWidget {
  const _HealthConnectCard();

  Future<void> _allow(WidgetRef ref) async {
    await ref.read(watchDataProvider).requestAccess();
    ref.invalidate(_watchStateProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(_watchStateProvider);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('From your watch app', style: text.titleMedium)),
              IconButton(
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.invalidate(_watchStateProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text('Could not check Health Connect.', style: text.bodyMedium),
            data: (s) => switch (s.status) {
              WatchStatus.unavailable => Text(
                'Health Connect is not available on this phone, so watch data cannot be read. Live heart rate by '
                'Bluetooth above still works.',
                style: text.bodyMedium,
              ),
              WatchStatus.needsInstall => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health Connect needs to be installed or updated first.', style: text.bodyMedium),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Get Health Connect',
                    icon: Icons.download_rounded,
                    onPressed: () => ref.read(watchDataProvider).install(),
                  ),
                ],
              ),
              WatchStatus.notAllowed => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Most watch apps (Fitbit, Samsung Health, Mi Fitness, Zepp, Noise, boAt, Garmin and others) can '
                    'share with Health Connect. Turn that on in your watch app, then allow Fittarc to read steps, '
                    'heart rate and sleep. Fittarc only reads, and keeps it on this phone.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Allow Fittarc to read',
                    icon: Icons.lock_open_rounded,
                    onPressed: () => _allow(ref),
                  ),
                ],
              ),
              WatchStatus.ready => _Snapshot(s.snapshot ?? const WatchSnapshot()),
            },
          ),
        ],
      ),
    );
  }
}

class _Snapshot extends StatelessWidget {
  const _Snapshot(this.data);

  final WatchSnapshot data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (data.isEmpty) {
      return Text(
        'Connected, but nothing has arrived yet. Open your watch app, let it sync, then refresh.',
        style: text.bodyMedium,
      );
    }
    String sleep(int m) => '${m ~/ 60} h ${m % 60} min';
    final items = <(IconData, String, String, String?)>[
      if (data.steps != null)
        (Icons.directions_walk_rounded, NumberFormat.decimalPattern().format(data.steps), 'Steps today', null),
      if (data.latestBpm != null)
        (
          Icons.favorite_rounded,
          '${data.latestBpm}',
          'Latest heart rate',
          data.latestBpmAt == null ? null : DateFormat.jm().format(data.latestBpmAt!),
        ),
      if (data.restingBpm != null) (Icons.bedtime_rounded, '${data.restingBpm}', 'Resting heart rate', null),
      if (data.sleepMinutes != null) (Icons.nightlight_round, sleep(data.sleepMinutes!), 'Sleep', null),
    ];
    return Column(
      children: [
        for (final (icon, value, label, note) in items)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: text.bodyMedium)),
                if (note != null) ...[Text(note, style: text.bodySmall), const SizedBox(width: 10)],
                Text(value, style: text.titleMedium),
              ],
            ),
          ),
      ],
    );
  }
}
