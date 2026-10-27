import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

enum WatchStatus {
  /// Health Connect is not on this phone and cannot be added.
  unavailable,

  /// It can be installed or updated from the store.
  needsInstall,

  /// Fittarc has not been allowed to read yet.
  notAllowed,
  ready,
}

/// What a watch (or any app) has put into Health Connect.
class WatchSnapshot {
  const WatchSnapshot({this.steps, this.latestBpm, this.latestBpmAt, this.restingBpm, this.sleepMinutes});

  final int? steps;
  final int? latestBpm;
  final DateTime? latestBpmAt;
  final int? restingBpm;
  final int? sleepMinutes;

  bool get isEmpty => steps == null && latestBpm == null && restingBpm == null && sleepMinutes == null;
}

/// Reading from Health Connect. Read-only: Fittarc never writes to it.
abstract class WatchData {
  Future<WatchStatus> status();

  /// Asks Health Connect to show its permission screen.
  Future<bool> requestAccess();

  Future<void> install();

  Future<WatchSnapshot> read(DateTime now);
}

final watchDataProvider = Provider<WatchData>((ref) => HealthConnectData());

const _types = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.SLEEP_SESSION,
];

class HealthConnectData implements WatchData {
  final _health = Health();
  bool _configured = false;

  Future<void> _init() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<WatchStatus> status() async {
    if (!Platform.isAndroid) return WatchStatus.unavailable;
    await _init();
    final s = await _health.getHealthConnectSdkStatus();
    if (s == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) return WatchStatus.needsInstall;
    if (s != HealthConnectSdkStatus.sdkAvailable) return WatchStatus.unavailable;
    final has = await _health.hasPermissions(_types) ?? false;
    return has ? WatchStatus.ready : WatchStatus.notAllowed;
  }

  @override
  Future<bool> requestAccess() async {
    await _init();
    return _health.requestAuthorization(_types);
  }

  @override
  Future<void> install() async {
    await _init();
    await _health.installHealthConnect();
  }

  @override
  Future<WatchSnapshot> read(DateTime now) async {
    await _init();
    final midnight = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(midnight, now);

    final recent = await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE, HealthDataType.RESTING_HEART_RATE],
      startTime: now.subtract(const Duration(hours: 24)),
      endTime: now,
    );
    int? latest;
    DateTime? latestAt;
    int? resting;
    DateTime? restingAt;
    for (final p in recent) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final bpm = v.numericValue.round();
      if (bpm < 30 || bpm > 250) continue;
      if (p.type == HealthDataType.HEART_RATE) {
        if (latestAt == null || p.dateTo.isAfter(latestAt)) {
          latest = bpm;
          latestAt = p.dateTo;
        }
      } else if (restingAt == null || p.dateTo.isAfter(restingAt)) {
        resting = bpm;
        restingAt = p.dateTo;
      }
    }

    // Sleep that ended since yesterday noon: last night, plus any nap.
    final sleep = await _health.getHealthDataFromTypes(
      types: [HealthDataType.SLEEP_SESSION],
      startTime: midnight.subtract(const Duration(hours: 12)),
      endTime: now,
    );
    var minutes = 0;
    for (final p in sleep) {
      minutes += p.dateTo.difference(p.dateFrom).inMinutes;
    }

    return WatchSnapshot(
      steps: steps,
      latestBpm: latest,
      latestBpmAt: latestAt,
      restingBpm: resting,
      sleepMinutes: minutes > 0 ? minutes : null,
    );
  }
}
