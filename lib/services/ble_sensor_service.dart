import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleSensorDevice {
  final BluetoothDevice device;
  final String id;
  final String name;
  final int rssi;
  final bool isConnected;

  const BleSensorDevice({
    required this.device,
    required this.id,
    required this.name,
    required this.rssi,
    required this.isConnected,
  });

  BleSensorDevice copyWith({
    BluetoothDevice? device,
    String? id,
    String? name,
    int? rssi,
    bool? isConnected,
  }) {
    return BleSensorDevice(
      device: device ?? this.device,
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class BleSensorService {
  BleSensorService._internal() {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
    });

    _scanSub = FlutterBluePlus.onScanResults.listen(
      _handleScanResults,
      onError: (Object error) {
        debugPrint('BLE scan error: $error');
      },
    );
  }

  static final BleSensorService instance = BleSensorService._internal();
  factory BleSensorService() => instance;

  final StreamController<List<BleSensorDevice>> _devicesController =
      StreamController<List<BleSensorDevice>>.broadcast();

  final StreamController<double> _dbController =
      StreamController<double>.broadcast();

  Stream<List<BleSensorDevice>> get devicesStream => _devicesController.stream;
  Stream<double> get dbStream => _dbController.stream;

  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dbCharacteristic;
  List<BleSensorDevice> _latestDevices = const [];

  BluetoothAdapterState get adapterState => _adapterState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BleSensorDevice> get latestDevices => _latestDevices;
  bool get isConnected => _connectedDevice != null;

  Future<bool> ensureBluetoothReady() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) return false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        // User may refuse or device may already be on.
      }
    }

    await FlutterBluePlus.adapterState
        .where((state) => state != BluetoothAdapterState.unknown)
        .first;

    return _adapterState == BluetoothAdapterState.on;
  }

  Future<void> startScan() async {
    final ready = await ensureBluetoothReady();
    if (!ready) {
      throw Exception('Bluetooth is not available or not enabled');
    }

    await FlutterBluePlus.stopScan();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 8),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDevice(
    BleSensorDevice bleDevice, {
    String? serviceUuid,
    String? characteristicUuid,
  }) async {
    await disconnect();

    final device = bleDevice.device;
    await device.connect(
  license: License.free,
  timeout: const Duration(seconds: 10),
);
    _connectedDevice = device;

    _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connectedDevice = null;
        _dbCharacteristic = null;
        _emitUpdatedConnectionState();
      }
    });

    if (serviceUuid != null &&
        serviceUuid.isNotEmpty &&
        characteristicUuid != null &&
        characteristicUuid.isNotEmpty) {
      await _subscribeToDbCharacteristic(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
      );
    }

    _emitUpdatedConnectionState();
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;

    await _connectionSub?.cancel();
    _connectionSub = null;

    final device = _connectedDevice;
    _connectedDevice = null;
    _dbCharacteristic = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _emitUpdatedConnectionState();
  }

  Future<void> _subscribeToDbCharacteristic(
    BluetoothDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final services = await device.discoverServices();

    BluetoothCharacteristic? found;

    for (final service in services) {
      if (!_uuidMatches(service.uuid, serviceUuid)) continue;

      for (final characteristic in service.characteristics) {
        if (_uuidMatches(characteristic.uuid, characteristicUuid)) {
          found = characteristic;
          break;
        }
      }
    }

    if (found == null) {
      throw Exception('BLE dB characteristic not found');
    }

    _dbCharacteristic = found;

    if (found.properties.notify || found.properties.indicate) {
      await found.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = found.onValueReceived.listen((bytes) {
        final db = _parseDbFromBytes(bytes);
        if (db != null) {
          _dbController.add(db);
        }
      });
    } else if (found.properties.read) {
      final bytes = await found.read();
      final db = _parseDbFromBytes(bytes);
      if (db != null) {
        _dbController.add(db);
      }
    } else {
      throw Exception('BLE characteristic does not support notify or read');
    }
  }

  bool _uuidMatches(Guid actual, String expected) {
    return actual.toString().toLowerCase() == expected.toLowerCase();
  }

  void _handleScanResults(List<ScanResult> results) {
    final Map<String, BleSensorDevice> unique = {};

    for (final result in results) {
      final id = result.device.remoteId.toString();
      final advName = result.advertisementData.advName.trim();
      final name = advName.isNotEmpty ? advName : 'Unknown BLE Device';

      unique[id] = BleSensorDevice(
        device: result.device,
        id: id,
        name: name,
        rssi: result.rssi,
        isConnected: _connectedDevice?.remoteId.toString() == id,
      );
    }

    _latestDevices = unique.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    _devicesController.add(_latestDevices);
  }

  void _emitUpdatedConnectionState() {
    _latestDevices = _latestDevices
        .map(
          (device) => device.copyWith(
            isConnected:
                _connectedDevice?.remoteId.toString() == device.id,
          ),
        )
        .toList();

    _devicesController.add(_latestDevices);
  }

  double? _parseDbFromBytes(List<int> bytes) {
    if (bytes.isEmpty) return null;

    try {
      if (bytes.length >= 4) {
        final bd = ByteData.sublistView(Uint8List.fromList(bytes));
        final value = bd.getFloat32(0, Endian.little);
        if (value.isFinite && value >= 0 && value <= 140) {
          return value;
        }
      }

      if (bytes.length >= 2) {
        final bd = ByteData.sublistView(Uint8List.fromList(bytes));
        final value = bd.getUint16(0, Endian.little).toDouble();
        if (value >= 0 && value <= 140) {
          return value;
        }
      }

      final single = bytes.first.toDouble();
      if (single >= 0 && single <= 140) {
        return single;
      }
    } catch (_) {}

    return null;
  }

  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _notifySub?.cancel();

    try {
      _devicesController.close();
    } catch (_) {}

    try {
      _dbController.close();
    } catch (_) {}
  }
}