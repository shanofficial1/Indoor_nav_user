import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleScannerService {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanStateSubscription;

  final StreamController<List<ScanResult>> _resultsController =
      StreamController<List<ScanResult>>.broadcast();

  final StreamController<bool> _scanStateController =
      StreamController<bool>.broadcast();

  bool _isScanning = false;

  Stream<List<ScanResult>> get results =>
      _resultsController.stream;

  Stream<bool> get scanState =>
      _scanStateController.stream;

  bool get isScanning => _isScanning;

  Future<void> startScan() async {
    if (_isScanning) {
      return;
    }

    // Listen to BLE scan results only once.
    _scanSubscription ??=
        FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isEmpty) {
          return;
        }

        // Send every received scan result.
        _resultsController.add(results);
      },
      onError: (error) {
        debugPrint(
          'BLE SCAN ERROR: $error',
        );
      },
    );

    // Listen to actual Android BLE scanner state.
    _scanStateSubscription ??=
        FlutterBluePlus.isScanning.listen(
      (scanning) {
        debugPrint(
          'BLE SCANNER STATE: '
          '${scanning ? "SCANNING" : "STOPPED"}',
        );

        _scanStateController.add(scanning);
      },
      onError: (error) {
        debugPrint(
          'BLE STATE ERROR: $error',
        );
      },
    );

    try {
      await FlutterBluePlus.startScan(
        // Android high-performance scanning.
        androidScanMode:
            AndroidScanMode.lowLatency,

        // Continue receiving repeated RSSI updates.
        continuousUpdates: true,

        // Do not intentionally skip updates.
        continuousDivisor: 1,

        // Deliver scan results individually.
        oneByOne: true,

        // No automatic timeout.
        timeout: null,
      );

      _isScanning = true;

      debugPrint(
        'BLE SCAN STARTED',
      );
    } catch (e) {
      _isScanning = false;

      debugPrint(
        'BLE START ERROR: $e',
      );

      rethrow;
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) {
      return;
    }

    try {
      await FlutterBluePlus.stopScan();

      debugPrint(
        'BLE SCAN STOPPED',
      );
    } catch (e) {
      debugPrint(
        'BLE STOP ERROR: $e',
      );
    }

    _isScanning = false;
  }

  Future<void> dispose() async {
    await stopScan();

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    await _scanStateSubscription?.cancel();
    _scanStateSubscription = null;

    await _resultsController.close();
    await _scanStateController.close();
  }
}