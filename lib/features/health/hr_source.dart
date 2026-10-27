import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'domain/live_hr.dart';

/// A heart-rate sensor found nearby.
class HrDevice {
  const HrDevice({required this.id, required this.name, this.rssi = 0});

  final String id;
  final String name;
  final int rssi;
}

/// Where live heart rate comes from. The real one is Bluetooth; tests give it
/// a pretend watch.
abstract class HrSource {
  /// Devices that offer the standard heart-rate service, growing as they are
  /// found. Errors (no permission, Bluetooth off) arrive on the stream.
  Stream<List<HrDevice>> scan();

  Future<void> stopScan();

  /// Readings from one device. The stream ends when the device disconnects.
  Stream<HrMeasurement> connect(String id);

  Future<void> disconnect();
}

final hrSourceProvider = Provider<HrSource>((ref) => BleHrSource());

final _heartRateService = Guid('180D');
final _heartRateMeasurement = Guid('2A37');

/// The standard Bluetooth "Heart Rate" profile. Chest straps use it, and so do
/// many watches when they are set to share (broadcast) their heart rate. Only
/// the heart-rate service is looked at; nothing else on the device is read.
class BleHrSource implements HrSource {
  BluetoothDevice? _device;
  StreamController<HrMeasurement>? _out;
  StreamSubscription<List<int>>? _valueSub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  static Future<void> _ready() async {
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('This phone does not support Bluetooth Low Energy.');
    }
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) {
      throw StateError(
        'Fittarc needs the "Nearby devices" permission to find your watch. Allow it in the phone settings.',
      );
    }
    final state = await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown)
        .timeout(const Duration(seconds: 4), onTimeout: () => BluetoothAdapterState.off);
    if (state != BluetoothAdapterState.on) {
      throw StateError('Bluetooth is off. Turn it on and try again.');
    }
  }

  @override
  Stream<List<HrDevice>> scan() async* {
    await _ready();
    await FlutterBluePlus.startScan(withServices: [_heartRateService], timeout: const Duration(seconds: 25));
    yield* FlutterBluePlus.scanResults.map(
      (list) => [
        for (final r in list)
          HrDevice(
            id: r.device.remoteId.str,
            name: r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.platformName,
            rssi: r.rssi,
          ),
      ],
    );
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  @override
  Stream<HrMeasurement> connect(String id) {
    final out = _out = StreamController<HrMeasurement>();
    _open(id, out);
    return out.stream;
  }

  Future<void> _open(String id, StreamController<HrMeasurement> out) async {
    try {
      await stopScan();
      final device = _device = BluetoothDevice.fromId(id);
      await device.connect(timeout: const Duration(seconds: 20), mtu: null);
      _stateSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && !out.isClosed) out.close();
      });
      final services = await device.discoverServices();
      final service = services.where((s) => s.uuid == _heartRateService).firstOrNull;
      final ch = service?.characteristics.where((c) => c.uuid == _heartRateMeasurement).firstOrNull;
      if (ch == null) {
        throw StateError('This device does not share its heart rate. Turn on heart rate sharing on the watch.');
      }
      _valueSub = ch.onValueReceived.listen((v) {
        final m = parseHeartRateMeasurement(v);
        if (m != null && !out.isClosed) out.add(m);
      });
      await ch.setNotifyValue(true);
    } catch (e) {
      if (!out.isClosed) {
        out.addError(e is StateError ? e : StateError('Could not connect to the watch. Move it close and try again.'));
        await out.close();
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await _valueSub?.cancel();
    await _stateSub?.cancel();
    _valueSub = _stateSub = null;
    final out = _out;
    _out = null;
    if (out != null && !out.isClosed) await out.close();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }
}
