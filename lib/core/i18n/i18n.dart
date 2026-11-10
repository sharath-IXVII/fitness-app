import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage.dart';
import 'kn.dart';

/// Languages the app can show.
enum AppLang {
  en('English', 'English', Locale('en', 'IN')),
  kn('ಕನ್ನಡ', 'Kannada', Locale('kn', 'IN'));

  const AppLang(this.native, this.english, this.locale);

  /// The language's own name, e.g. "ಕನ್ನಡ".
  final String native;
  final String english;
  final Locale locale;
}

/// The language now in use. Widgets read text through [tr].
AppLang currentLang = AppLang.en;

const _tables = <AppLang, Map<String, String>>{AppLang.kn: kannada};

/// [en] in the current language, or [en] itself when there's no translation
/// yet (so a missing line never shows as blank).
String tr(String en) {
  if (currentLang == AppLang.en) return en;
  return _tables[currentLang]?[en] ?? en;
}

/// The chosen language, saved on the phone. Null until the user picks one
/// (the first screen asks).
class LangNotifier extends Notifier<AppLang?> {
  static const key = 'app.lang.v1';

  @override
  AppLang? build() {
    final prefs = ref.read(sharedPrefsProvider);
    // People who used FittArc before languages existed keep English.
    final saved =
        AppLang.values.asNameMap()[prefs.getString(key)] ?? (prefs.containsKey('profile.v1') ? AppLang.en : null);
    currentLang = saved ?? AppLang.en;
    return saved;
  }

  Future<void> set(AppLang lang) async {
    currentLang = lang;
    state = lang;
    await ref.read(sharedPrefsProvider).setString(key, lang.name);
  }
}

final langProvider = NotifierProvider<LangNotifier, AppLang?>(LangNotifier.new);
