import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Spoken cues during guided workouts, using the phone's own text-to-speech
/// (free and offline). Failures are ignored: the workout works silently.
class VoiceCoach {
  FlutterTts? _tts;

  void say(String text) => unawaited(_speak(text));

  Future<void> _speak(String text) async {
    try {
      final tts = _tts ??= await _create();
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('voice coach: $e');
    }
  }

  Future<FlutterTts> _create() async {
    final tts = FlutterTts();
    await tts.setSpeechRate(0.5);
    await tts.setPitch(1.0);
    return tts;
  }

  void stop() {
    final tts = _tts;
    if (tts != null) unawaited(tts.stop().catchError((_) => null));
  }
}

final voiceCoachProvider = Provider<VoiceCoach>((ref) {
  final coach = VoiceCoach();
  ref.onDispose(coach.stop);
  return coach;
});
