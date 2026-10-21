import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:intl/intl.dart';
import 'package:pedometer_2/pedometer_2.dart';

import '../../core/storage.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/step_fusion.dart';

class StepsState {
  const StepsState({
    this.day = const StepDay(),
    this.motion = Motion.unknown,
    this.sensorAvailable = false,
    this.permissionDenied = false,
    this.walking = false,
    this.walkStarted,
    this.walkMeters = 0,
  });

  final StepDay day;
  final Motion motion;
  final bool sensorAvailable;
  final bool permissionDenied;

  /// A GPS walk is being recorded.
  final bool walking;
  final DateTime? walkStarted;
  final double walkMeters;

  StepsState copyWith({
    StepDay? day,
    Motion? motion,
    bool? sensorAvailable,
    bool? permissionDenied,
    bool? walking,
    DateTime? walkStarted,
    double? walkMeters,
  }) => StepsState(
    day: day ?? this.day,
    motion: motion ?? this.motion,
    sensorAvailable: sensorAvailable ?? this.sensorAvailable,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    walking: walking ?? this.walking,
    walkStarted: walkStarted ?? this.walkStarted,
    walkMeters: walkMeters ?? this.walkMeters,
  );
}

/// Live step tracking: the hardware step counter (minus vehicle time) plus
/// optional GPS walks. Verified steps are written to the daily log.
class StepsNotifier extends Notifier<StepsState> {
  static final _keyDate = DateFormat('yyyy-MM-dd');
  static String _key(DateTime d) => 'steps.v1.${_keyDate.format(d)}';

  StreamSubscription<int>? _sensor;
  StreamSubscription<Activity>? _activity;
  StreamSubscription<Position>? _gps;
  Position? _lastFix;
  DateTime _day = DateTime.now();
  DateTime _lastLogWrite = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  StepsState build() {
    ref.onDispose(_stopAll);
    return StepsState(day: _load(DateTime.now()));
  }

  StepDay _load(DateTime d) {
    final raw = ref.read(sharedPrefsProvider).getString(_key(d));
    return raw == null ? const StepDay() : StepDay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Starts sensor + activity tracking. Safe to call more than once.
  Future<void> start() async {
    if (!supported || _sensor != null) return;
    final activity = FlutterActivityRecognition.instance;
    var perm = await activity.checkPermission();
    if (perm != ActivityPermission.GRANTED) perm = await activity.requestPermission();
    if (perm != ActivityPermission.GRANTED) {
      state = state.copyWith(permissionDenied: true);
      return;
    }
    state = state.copyWith(permissionDenied: false);
    _activity = activity.activityStream.listen(_onActivity, onError: (_) {});
    _sensor = Pedometer().stepCountStream().listen(
      _onSensor,
      onError: (_) => state = state.copyWith(sensorAvailable: false),
    );
  }

  void _onActivity(Activity a) {
    if (a.confidence == ActivityConfidence.LOW) return;
    state = state.copyWith(
      motion: switch (a.type) {
        ActivityType.IN_VEHICLE => Motion.vehicle,
        ActivityType.ON_BICYCLE => Motion.cycling,
        ActivityType.RUNNING => Motion.running,
        ActivityType.WALKING => Motion.walking,
        ActivityType.STILL => Motion.still,
        ActivityType.UNKNOWN => Motion.unknown,
      },
    );
  }

  void _rollDayIfNeeded() {
    final now = DateTime.now();
    if (now.day == _day.day && now.month == _day.month && now.year == _day.year) return;
    // New day: keep the raw counter so the first reading tomorrow has a baseline.
    final carry = state.day.lastCumulative;
    _day = now;
    state = state.copyWith(day: _load(now).copyWith(lastCumulative: carry));
  }

  void _onSensor(int cumulative) {
    _rollDayIfNeeded();
    state = state.copyWith(sensorAvailable: true, day: StepFusion.onSensor(state.day, cumulative, state.motion));
    _persist();
  }

  Future<void> _persist({bool force = false}) async {
    await ref.read(sharedPrefsProvider).setString(_key(_day), jsonEncode(state.day.toJson()));
    // Throttle daily-log writes; they trigger a rebuild of the dashboard.
    final now = DateTime.now();
    if (!force && now.difference(_lastLogWrite) < const Duration(seconds: 15)) return;
    _lastLogWrite = now;
    final verified = state.day.verified;
    await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(steps: verified));
  }

  /// Starts recording a GPS walk. Returns false if location isn't allowed.
  Future<bool> startWalk() async {
    if (!supported) return false;
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return false;
    _lastFix = null;
    state = state.copyWith(walking: true, walkStarted: DateTime.now(), walkMeters: 0);
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen(_onFix, onError: (_) {});
    return true;
  }

  void _onFix(Position fix) {
    if (fix.accuracy > StepFusion.maxAccuracy) return;
    final last = _lastFix;
    _lastFix = fix;
    if (last == null) return;
    final meters = StepFusion.distance(last.latitude, last.longitude, fix.latitude, fix.longitude);
    final seconds = fix.timestamp.difference(last.timestamp).inMilliseconds / 1000;
    final speed = fix.speed > 0 ? fix.speed : (seconds > 0 ? meters / seconds : 0.0);
    final stride = ref.read(targetsProvider)?.strideM ?? 0.72;
    final before = state.day.gpsMeters;
    final day = StepFusion.onGpsSegment(state.day, meters: meters, speed: speed, strideM: stride);
    state = state.copyWith(day: day, walkMeters: state.walkMeters + (day.gpsMeters - before));
    _persist();
  }

  Future<void> stopWalk() async {
    await _gps?.cancel();
    _gps = null;
    state = StepsState(
      day: state.day,
      motion: state.motion,
      sensorAvailable: state.sensorAvailable,
      permissionDenied: state.permissionDenied,
    );
    await _persist(force: true);
  }

  void _stopAll() {
    _sensor?.cancel();
    _activity?.cancel();
    _gps?.cancel();
  }
}

final stepsProvider = NotifierProvider<StepsNotifier, StepsState>(StepsNotifier.new);

/// Last 7 days of verified steps (oldest first), for the weekly chart.
final weekStepsProvider = Provider<List<(DateTime, int)>>((ref) {
  final logs = ref.watch(dailyLogsProvider);
  final today = DateTime.now();
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        return (d, logs[d]?.steps ?? 0);
      }(),
  ];
});
