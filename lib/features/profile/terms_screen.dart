import '../../core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/page_background.dart';
import 'terms.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Terms of use'))),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text('Last updated $termsUpdated', style: text.bodySmall),
            for (final (title, body) in termsSections) ...[
              const SizedBox(height: 20),
              Text(title, style: text.titleMedium),
              const SizedBox(height: 6),
              Text(body, style: text.bodyMedium?.copyWith(height: 1.55)),
            ],
          ],
        ),
      ),
    );
  }
}
