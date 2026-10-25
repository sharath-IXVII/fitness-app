// Writes the public web pages (docs/privacy.md, docs/terms.md) from the text
// shown in the app, so the two never drift apart.
//   dart run tools/gen_policy_pages.dart
import 'dart:io';

import 'package:fitalarm/features/profile/privacy_policy.dart';
import 'package:fitalarm/features/profile/terms.dart';

void write(String file, String title, String permalink, String updated, List<(String, String)> sections) {
  final b = StringBuffer('---\ntitle: $title\npermalink: $permalink\n---\n\n# $title\n\n_Last updated: ${updated}_\n');
  for (final (t, body) in sections) {
    b.write('\n## $t\n\n$body\n');
  }
  File('docs/$file').writeAsStringSync(b.toString());
}

void main() {
  write('privacy.md', 'Fittarc privacy policy', '/privacy/', privacyUpdated, privacySections);
  write('terms.md', 'Fittarc terms of use', '/terms/', termsUpdated, termsSections);
}
