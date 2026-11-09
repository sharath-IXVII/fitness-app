import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../clubs/clubs_providers.dart' show hiddenPeopleProvider;
import '../../friends/friends_providers.dart';
import '../snap_share_backend.dart';
import '../snap_share_providers.dart';

/// "Snaps from friends" on the Friends page: today's snaps, tap to view.
class SnapInbox extends ConsumerWidget {
  const SnapInbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenPeopleProvider);
    final snaps = [
      for (final s in ref.watch(snapInboxProvider).value ?? const <SharedSnap>[])
        if (!hidden.contains(s.from)) s,
    ];
    if (snaps.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Snaps from friends', style: text.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snaps.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final s = snaps[i];
                return GestureDetector(
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _SnapViewer(snap: s))),
                  child: SizedBox(
                    width: 74,
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2.5),
                          ),
                          child: ClipOval(child: Image.memory(s.image, fit: BoxFit.cover, cacheWidth: 200)),
                        ),
                        const SizedBox(height: 4),
                        Text(s.fromName, style: text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapViewer extends ConsumerWidget {
  const _SnapViewer({required this.snap});

  final SharedSnap snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = SharedSnap.lifetime - clock.now().difference(snap.at);
    final text = Theme.of(context).textTheme;
    final me = ref.watch(friendsUidProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(snap.fromName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (a) async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              if (a == 'report' && me != null) {
                await ref.read(snapShareBackendProvider)?.report(me, snap).catchError((_) {});
                messenger.showSnackBar(const SnackBar(content: Text('Thanks. We will review it.')));
              } else if (a == 'block' && me != null) {
                await ref.read(hiddenPeopleProvider.notifier).hide(snap.from);
                await ref.read(friendsBackendProvider)?.block(me, snap.from).catchError((_) {});
                nav.pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(value: 'block', child: Text('Block ${snap.fromName}')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(child: InteractiveViewer(child: Image.memory(snap.image))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (snap.caption.isNotEmpty)
                  Text(
                    snap.caption,
                    style: text.titleMedium?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 4),
                Text(
                  'Disappears in ${left.inHours > 0 ? '${left.inHours} h' : '${left.inMinutes.clamp(1, 60)} min'}',
                  style: text.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
