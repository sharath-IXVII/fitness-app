import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
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
    this.useLocation = false,
    this.gpsTracking = false,
  });

  final StepDay day;
  final Motion motion;
  final bool sensorAvailable;
  final bool permissionDenied;

  /// A GPS walk is being recorded.
  final bool walking;
  final DateTime? walkStarted;
  final double walkMeters;

  /// The user chose to merge GPS with the step sensor.
  final bool useLocation;

  /// GPS is running right now (only while the app is open).
  final bool gpsTracking;

  StepsState copyWith({
    StepDay? day,
    Motion? motion,
    bool? sensorAvailable,
    bool? permissionDenied,
    bool? walking,
    DateTime? walkStarted,
    double? walkMeters,
    bool? useLocation,
    bool? gpsTracking,
  }) => StepsState(
    day: day ?? this.day,
    motion: motion ?? this.motion,
    sensorAvailable: sensorAvailable ?? this.sensorAvailable,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    walking: walking ?? this.walking,
    walkStarted: walkStarted ?? this.walkStarted,
    walkMeters: walkMeters ?? this.walkMeters,
    useLocation: useLocation ?? this.useLocation,
    gpsTracking: gpsTracking ?? this.gpsTracking,
  );
}

/// Live step tracking. The hardware step counter always runs (minus time in
/// a vehicle). If the user allows location, GPS runs alongside it while the
/// app is open: it fills in steps the sensor missed, measures real distance
/// and spots car or bike rides by speed. Without location, the sensor alone
/// counts. Merged steps are written to the daily log.
class StepsNotifier extends Notifier<StepsState> {
  static final _keyDate = DateFormat('yyyy-MM-dd');
  static String _key(DateTime d) => 'steps.v1.${_keyDate.format(d)}';
  static const _locationKey = 'steps.location.v1';

  AppLifecycleListener? _lifecycle;
  DateTime? _lastGoodFix;
  DateTime _gpsVehicleUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastStepAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    return StepsState(
      day: _load(DateTime.now()),
      useLocation: ref.read(sharedPrefsProvider).getBool(_locationKey) ?? false,
    );
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
    // GPS only while the app is in the foreground (no background location).
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        if (state.useLocation) _startGps();
      },
      onPause: () {
        if (!state.walking) _stopGps();
      },
    );
    if (state.useLocation) await _startGps();
  }

  /// Turns merging with GPS on or off. Returns false if location isn't
  /// available or allowed, in which case the sensor keeps counting alone.
  Future<bool> setUseLocation(bool on) async {
    if (on) {
      if (!supported || !await _locationAllowed()) return false;
      state = state.copyWith(useLocation: true);
      await ref.read(sharedPrefsProvider).setBool(_locationKey, true);
      await _startGps();
      return true;
    }
    state = state.copyWith(useLocation: false);
    await ref.read(sharedPrefsProvider).setBool(_locationKey, false);
    if (!state.walking) await _stopGps();
    return true;
  }

  Future<bool> _locationAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p == LocationPermission.whileInUse || p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startGps() async {
    if (_gps != null || !supported) return;
    try {
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.whileInUse && p != LocationPermission.always) {
        state = state.copyWith(gpsTracking: false);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;
    } catch (_) {
      return;
    }
    _lastFix = null;
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 8),
    ).listen(_onFix, onError: (_) => _stopGps());
    state = state.copyWith(gpsTracking: true);
  }

  Future<void> _stopGps() async {
    await _gps?.cancel();
    _gps = null;
    _lastFix = null;
    _lastGoodFix = null;
    state = state.copyWith(gpsTracking: false);
  }

  /// GPS counts as tracking only while fixes keep arriving.
  bool get _gpsFresh {
    final t = _lastGoodFix;
    return _gps != null && t != null && DateTime.now().difference(t) < const Duration(minutes: 2);
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
    if (state.day.lastCumulative != null && cumulative != state.day.lastCumulative) _lastStepAt = DateTime.now();
    final day = StepFusion.onSensor(
      state.day,
      cumulative,
      state.motion,
      gpsTracking: _gpsFresh,
      gpsVehicle: DateTime.now().isBefore(_gpsVehicleUntil),
    );
    state = state.copyWith(sensorAvailable: true, day: day);
    _persist();
  }

  Future<void> _persist({bool force = false}) async {
    await ref.read(sharedPrefsProvider).setString(_key(_day), jsonEncode(state.day.toJson()));
    // Throttle daily-log writes; they trigger a rebuild of the dashboard.
    final now = DateTime.now();
    if (!force && now.difference(_lastLogWrite) < const Duration(seconds: 15)) return;
    _lastLogWrite = now;
    final total = state.day.total;
    await ref.read(dailyLogsProvider.notifier).update((l) => l.copyWith(steps: total));
  }

  /// Starts recording a walk (time and distance). Returns false if location
  /// isn't allowed.
  Future<bool> startWalk() async {
    if (!supported || !await _locationAllowed()) return false;
    await _startGps();
    if (_gps == null) return false;
    state = state.copyWith(walking: true, walkStarted: DateTime.now(), walkMeters: 0);
    return true;
  }

  void _onFix(Position fix) {
    if (fix.accuracy > StepFusion.maxAccuracy) return;
    _rollDayIfNeeded();
    _lastGoodFix = DateTime.now();
    final last = _lastFix;
    _lastFix = fix;
    if (last == null) return;
    final meters = StepFusion.distance(last.latitude, last.longitude, fix.latitude, fix.longitude);
    final seconds = fix.timestamp.difference(last.timestamp).inMilliseconds / 1000;
    final speed = fix.speed > 0 ? fix.speed : (seconds > 0 ? meters / seconds : 0.0);
    if (StepFusion.isVehicleSpeed(speed)) {
      // Steps the sensor counts in the next minute or so are bumps.
      _gpsVehicleUntil = DateTime.now().add(const Duration(seconds: 90));
    }
    // GPS drifts even when standing still; only trust its distance while the
    // step sensor or motion detection also says the user is on the move.
    final moving =
        DateTime.now().difference(_lastStepAt) < const Duration(seconds: 60) ||
        state.motion == Motion.walking ||
        state.motion == Motion.running;
    if (!moving) return;
    final stride = ref.read(targetsProvider)?.strideM ?? 0.72;
    final before = state.day.gpsMeters;
    final day = StepFusion.onGpsSegment(state.day, meters: meters, speed: speed, strideM: stride);
    state = state.copyWith(
      day: day,
      walkMeters: state.walking ? state.walkMeters + (day.gpsMeters - before) : state.walkMeters,
    );
    _persist();
  }

  Future<void> stopWalk() async {
    if (!state.useLocation) await _stopGps();
    state = StepsState(
      day: state.day,
      motion: state.motion,
      sensorAvailable: state.sensorAvailable,
      permissionDenied: state.permissionDenied,
      useLocation: state.useLocation,
      gpsTracking: state.gpsTracking,
    );
    await _persist(force: true);
  }

  void _stopAll() {
    _sensor?.cancel();
    _activity?.cancel();
    _gps?.cancel();
    _lifecycle?.dispose();
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
