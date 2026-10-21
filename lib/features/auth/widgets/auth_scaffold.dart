import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../auth_providers.dart';

/// Shared frame for the auth screens: back button, title, subtitle, content,
/// and a demo-mode note when no backend is configured.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.footer});

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final demo = ref.watch(authServiceProvider).isDemo;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: Navigator.of(context).canPop() ? const BackButton() : null),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.headlineMedium),
                    const SizedBox(height: 8),
                    Text(subtitle, style: text.bodyMedium?.copyWith(height: 1.5)),
                    const SizedBox(height: 28),
                    child,
                  ],
                ).animate().fadeIn(duration: 250.ms).moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
            if (demo) const DemoNote(),
            if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: footer),
          ],
        ),
      ),
    );
  }
}

class DemoNote extends StatelessWidget {
  const DemoNote({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Demo mode — sign-in is simulated until Firebase is connected. SMS code: 123456.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.amber),
          ),
        ),
      ],
    ),
  );
}
