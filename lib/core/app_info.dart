abstract final class AppInfo {
  static const name = 'FittiePi';
  static const tagline = 'The Rise of Arcs';

  /// Shown on the opening screen every time the app starts.
  static const sponsor = 'GetYr_io';

  /// Android application id. Keep in sync with android/app/build.gradle.kts.
  static const packageId = 'com.fittiepi.app';

  /// Where friends can get the app.
  static const storeUrl = 'https://play.google.com/store/apps/details?id=$packageId';
}
