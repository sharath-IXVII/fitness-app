import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Plain page canvas. Kept as a widget so every screen shares one surface.
class PageBackground extends StatelessWidget {
  const PageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: AppColors.background, child: child);
}
