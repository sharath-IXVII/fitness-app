import 'package:fitalarm/features/share/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final (name, data) in [
    ('streak', ShareCardData.streak(30)),
    ('workout', ShareCardData.workout(name: 'Full body burn: 25 minutes', seconds: 1520, kcal: 210, streak: 12)),
    ('badge', ShareCardData.badge(title: 'Master of Winter 2026', description: 'Every daily goal in the Winter Arc')),
  ]) {
    testWidgets('the $name card fits', (t) async {
      await t.pumpWidget(MaterialApp(home: Center(child: ShareCard(data: data))));
      expect(t.takeException(), isNull);
      expect(find.text(data.headline), findsOneWidget);
    });
  }

  test('share texts name FittArc', () {
    expect(ShareCardData.streak(7).shareText, contains('7-day streak'));
    expect(ShareCardData.workout(name: 'Core', seconds: 600, kcal: 80).stats.first.$1, '10 min');
    expect(streakMilestones, containsAll([7, 30, 100]));
  });
}
