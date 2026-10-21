import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Advances time without pumpAndSettle, which never settles because of the
/// looping background animations.
Future<void> _wait(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await _wait(t);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in [const Size(360, 640), const Size(412, 915)]) {
    testWidgets('onboarding to home on a ${size.width.toInt()}x${size.height.toInt()} phone', (t) async {
      t.view.physicalSize = size * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(
        ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const FitAlarmApp()),
      );
      await _wait(t, 3200);

      await _tap(t, 'Get started');
      await t.enterText(find.byType(TextField), 'Sharath Kumar');
      await _wait(t, 200);
      await _tap(t, 'Continue');
      await _tap(t, 'Male');
      await _tap(t, 'Continue'); // about
      await _tap(t, 'Continue'); // height
      await _tap(t, 'Continue'); // weight
      await _tap(t, 'Build muscle');
      await _tap(t, 'Continue');
      await _tap(t, 'Lightly active');
      await _tap(t, 'Continue');
      await _tap(t, 'Vegetarian');
      await _tap(t, 'Continue');
      await _tap(t, 'Beginner');
      await _tap(t, 'Continue');
      await _tap(t, 'Build my plan');
      expect(find.textContaining('Your plan is ready'), findsOneWidget);

      await _tap(t, "Let's go");
      await _wait(t, 1500);
      expect(find.text("Today's score"), findsOneWidget);
      expect(prefs.getString('profile.v1'), contains('Sharath Kumar'));

      // A default alarm was created from the wake-up time.
      expect(prefs.getString('alarms.v1'), contains('"routine":"beginner"'));

      // Logging water updates the tile.
      await t.scrollUntilVisible(find.text('+250 ml'), 200, scrollable: find.byType(Scrollable).first);
      await _wait(t, 300);
      await _tap(t, '+250 ml');
      expect(find.textContaining('0.25 /'), findsOneWidget);

      // Alarm tab: alarm card, then the editor sheet.
      await _tap(t, 'Alarm');
      expect(find.text('Alarms'), findsOneWidget);
      expect(find.textContaining('Beginner routine'), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_rounded).first);
      await _wait(t);
      expect(find.text('New alarm'), findsOneWidget);
      await t.drag(find.text('Routine to stop it'), const Offset(0, -300));
      await _wait(t, 300);
      await _tap(t, 'Save alarm');
      await _wait(t);
      expect(find.textContaining('Beginner routine'), findsNWidgets(2));
      expect(find.textContaining('Alarm set for'), findsOneWidget);
      await _wait(t, 5000); // let the snackbar go

      // Custom routine builder.
      await t.scrollUntilVisible(find.text('Custom'), 200, scrollable: find.byType(Scrollable).first);
      await _tap(t, 'Custom');
      expect(find.text('New routine'), findsOneWidget);
      await _tap(t, 'Save routine');
      expect(find.text('New routine'), findsNothing);
      await t.scrollUntilVisible(find.text('My routine'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('My routine'), findsOneWidget);
    });
  }
}
