import 'package:flutter/material.dart';

import '../../core/widgets/page_background.dart';
import 'privacy_policy.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text('Last updated $privacyUpdated', style: text.bodySmall),
            for (final (title, body) in privacySections) ...[
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
