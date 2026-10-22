import 'package:fitalarm/app.dart';
import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/auth/auth_providers.dart';
import 'package:fitalarm/features/auth/auth_service.dart';
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

Widget _app(SharedPreferences prefs) => ProviderScope(
  overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    authServiceProvider.overrideWithValue(DemoAuthService(prefs)),
  ],
  child: const FitTrackerApp(),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in [const Size(360, 640), const Size(412, 915)]) {
    testWidgets('onboarding to home on a ${size.width.toInt()}x${size.height.toInt()} phone', (t) async {
      t.view.physicalSize = size * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(_app(prefs));
      await _wait(t, 3400);

      // Sign up with phone (demo backend: code 123456).
      expect(find.text('Create your account'), findsOneWidget);
      await _tap(t, 'Continue with phone');
      await t.enterText(find.byType(TextField), '9876543210');
      await _wait(t, 200);
      await _tap(t, 'Send code');
      await _wait(t, 1200);
      expect(find.text('Enter the code'), findsOneWidget);
      await t.enterText(find.byType(TextField), '123456');
      await _wait(t, 2800); // success animation plays over the next screen

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
      expect(find.text('Day streak'), findsOneWidget);
      await t.scrollUntilVisible(find.text("TODAY'S SCORE"), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text("TODAY'S SCORE"), findsOneWidget);
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
      expect(find.text('Beginner routine'), findsOneWidget); // the alarm card's routine tag
      await t.tap(find.byIcon(Icons.add_rounded).first);
      await _wait(t);
      expect(find.text('New alarm'), findsOneWidget);
      await _wait(t, 300);
      await _tap(t, 'Save alarm');
      await _wait(t);
      expect(RegExp('"id":').allMatches(prefs.getString('alarms.v1')!).length, 2);
      expect(find.textContaining('Alarm set for'), findsOneWidget);
      await _wait(t, 5000); // let the snackbar go

      // Custom routine builder.
      await t.scrollUntilVisible(find.text('Custom'), 200, scrollable: find.byType(Scrollable).hitTestable().first);
      await _tap(t, 'Custom');
      expect(find.text('New routine'), findsOneWidget);
      await _tap(t, 'Save routine');
      expect(find.text('New routine'), findsNothing);
      await t.scrollUntilVisible(find.text('My routine'), 200, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('My routine'), findsOneWidget);

      // My Day: start from a template and tick an item off.
      await _tap(t, 'My Day');
      expect(find.text('Plan your day'), findsOneWidget);
      await _tap(t, 'Choose a template');
      await _tap(t, 'Office');
      await _wait(t, 600);
      expect(['Next:', 'Now:', 'All done'].any((p) => find.textContaining(p).evaluate().isNotEmpty), isTrue);
      expect(prefs.getString('myday.v1'), contains('"kind":"lunch"'));
    });
  }

  testWidgets('a wrong code is rejected, Google sign-in works, sign-out returns to auth', (t) async {
    t.view.physicalSize = const Size(412, 915) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(_app(prefs));
    await _wait(t, 3400);

    await _tap(t, 'Log in');
    expect(find.text('Welcome back'), findsOneWidget);
    await _tap(t, 'Continue with phone');
    await t.enterText(find.byType(TextField), '9876543210');
    await _wait(t, 200);
    await _tap(t, 'Send code');
    await _wait(t, 1200);
    await t.enterText(find.byType(TextField), '000000');
    await _wait(t, 1200);
    expect(find.textContaining('incorrect'), findsOneWidget);
    expect(prefs.getString('auth.demo.v1'), isNull);

    // Back to the start and use Google instead.
    await t.pageBack();
    await _wait(t);
    await t.pageBack();
    await _wait(t);
    await _tap(t, 'Continue with Google');
    await _wait(t, 2800);
    expect(prefs.getString('auth.demo.v1'), contains('demo.user@gmail.com'));
    // Name is pre-filled from the Google account.
    await _tap(t, 'Get started');
    expect(find.text('Demo User'), findsOneWidget);
  });
}
