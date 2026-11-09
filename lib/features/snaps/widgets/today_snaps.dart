import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/photo_store.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../domain/food_snap.dart';
import '../snap_screen.dart';
import '../snaps_providers.dart';

/// Today's food snaps in a row; tap one to see and share it. Hidden until
/// the first snap of the day.
class TodaySnaps extends ConsumerWidget {
  const TodaySnaps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snaps = ref.watch(todaySnapsProvider);
    if (snaps.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's snaps (${snaps.length})", style: text.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snaps.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _SnapTile(snap: snaps[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapTile extends StatelessWidget {
  const _SnapTile({required this.snap});

  final FoodSnap snap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.snap, extra: SnapArgs(snap.id)),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 96,
                height: 88,
                child: FutureBuilder<File?>(
                  future: snap.photo == null ? null : PhotoStore.file(snap.photo!),
                  builder: (_, f) => f.data != null
                      ? Image.file(f.data!, fit: BoxFit.cover, cacheWidth: 288)
                      : ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(Icons.restaurant_rounded, color: AppColors.primary),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(snap.meal.label, style: text.labelMedium, maxLines: 1),
            Text('${snap.total.kcal.round()} kcal', style: text.bodySmall, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
