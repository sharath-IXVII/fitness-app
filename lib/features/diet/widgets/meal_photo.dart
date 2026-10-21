import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/photo_store.dart';
import '../../../core/theme/app_colors.dart';

/// Thumbnail of a meal photo stored on this phone; empty if it's missing.
class MealPhoto extends StatelessWidget {
  const MealPhoto({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: PhotoStore.file(name),
    builder: (_, snap) {
      final f = snap.data;
      if (f == null) return SizedBox.square(dimension: size);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: AppColors.surfaceHigh,
          child: Image.file(f, width: size, height: size, fit: BoxFit.cover, cacheWidth: (size * 3).round()),
        ),
      );
    },
  );
}
