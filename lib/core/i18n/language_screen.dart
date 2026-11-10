import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import '../widgets/page_background.dart';
import 'i18n.dart';

/// The very first screen: pick the app's language. Shown once; it can be
/// changed later in Profile.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final now = ref.watch(langProvider);
    return Scaffold(
      appBar: fromSettings ? AppBar(title: Text(tr('Language'))) : null,
      body: PageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                if (!fromSettings) const Center(child: AppLogo(size: 84, heroTag: null)),
                const SizedBox(height: 24),
                Text('Choose your language', textAlign: TextAlign.center, style: text.headlineSmall),
                Text('ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ', textAlign: TextAlign.center, style: text.titleMedium),
                const SizedBox(height: 28),
                for (final l in AppLang.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: now == l ? AppColors.primarySoft : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await ref.read(langProvider.notifier).set(l);
                          if (fromSettings && context.mounted) Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: now == l ? AppColors.primary : AppColors.stroke, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(l.native, style: text.titleLarge)),
                              if (l.native != l.english) Text(l.english, style: text.bodyMedium),
                              if (now == l) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.check_circle_rounded, color: AppColors.primary),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
