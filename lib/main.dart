import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'models/building_config.dart';
import 'services/config_service.dart';
import 'services/route_service.dart';
import 'services/ble_scanner_service.dart';
import 'services/rssi_filter_service.dart';

import 'widgets/indoor_map.dart';
import 'screens/destination_search_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const IndoorNavUserApp(),
  );
}

class IndoorNavUserApp extends StatelessWidget {
  const IndoorNavUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Indoor Navigation',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ConfigService _configService =
      ConfigService();

  final RouteService _routeService =
      RouteService();

  final BleScannerService _bleScanner =
      BleScannerService();

  final RssiFilterService _rssiFilter =
      RssiFilterService(
    maxSamples: 10,
  );

  StreamSubscription<List<ScanResult>>?
      _bleSubscription;

  BuildingConfig? config;

  String? error;

  // Current node detected from BLE.
  String? currentNodeId;

  // Current strongest beacon.
  String? currentBeaconId;

  // Current RSSI.
  double? currentRssi;

  // Destination node.
  String? destinationNodeId;

  // Calculated route.
  List<String> currentRoute = [];

  // Filtered RSSI for each beacon.
  final Map<String, double> _filteredRssi = {};

  bool _bleScanning = false;

  @override
  void initState() {
    super.initState();

    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final loadedConfig =
          await _configService.loadConfig();

      if (!mounted) return;

      setState(() {
        config = loadedConfig;
      });

      // Start BLE only after configuration loaded.
      _startBleScanning();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    }
  }

  Future<void> _startBleScanning() async {
    if (_bleScanning) {
      return;
    }

    if (config == null) {
      return;
    }

    _bleSubscription ??=
        _bleScanner.results.listen(
      _processBleResults,
    );

    try {
      await _bleScanner.startScan();

      if (mounted) {
        setState(() {
          _bleScanning = true;
        });
      }

      debugPrint(
        'USER APP BLE SCANNING STARTED',
      );
    } catch (e) {
      debugPrint(
        'USER APP BLE ERROR: $e',
      );
    }
  }

  void _processBleResults(
    List<ScanResult> results,
  ) {
    final appConfig = config;

    if (appConfig == null) {
      return;
    }

    for (final result in results) {
      final mac =
          result.device.remoteId.str;

      // Check whether this is one of our
      // configured beacons.
      final configuredBeacon =
          appConfig.beacons.where(
        (beacon) =>
            beacon.mac.toUpperCase() ==
            mac.toUpperCase(),
      );

      if (configuredBeacon.isEmpty) {
        continue;
      }

      // Add raw RSSI to moving average.
      final filtered =
          _rssiFilter.addSample(
        mac,
        result.rssi,
      );

      _filteredRssi[mac] = filtered;

      debugPrint(
        'POSITION BLE | '
        'MAC: $mac | '
        'RAW: ${result.rssi} | '
        'FILTERED: ${filtered.toStringAsFixed(1)}',
      );
    }

    if (_filteredRssi.isEmpty) {
      return;
    }

    // Find strongest beacon.
    String? strongestMac;
    double? strongestRssi;

    for (final entry
        in _filteredRssi.entries) {
      if (strongestRssi == null ||
          entry.value > strongestRssi) {
        strongestMac = entry.key;
        strongestRssi = entry.value;
      }
    }

   if (strongestMac == null || strongestRssi == null) {
  return;
}

final strongestBeacon =
    appConfig.beacons.where(
  (beacon) =>
      beacon.mac.toUpperCase() ==
      strongestMac!.toUpperCase(),
);

    if (strongestBeacon.isEmpty) {
      return;
    }

    final beacon =
        strongestBeacon.first;

    final newNodeId = beacon.nodeId;

    if (newNodeId == null) {
      return;
    }

    // Update only when necessary.
    if (mounted) {
      setState(() {
        currentBeaconId = beacon.id;
        currentNodeId = newNodeId;
        currentRssi = strongestRssi;
      });
    }

    debugPrint(
      'CURRENT POSITION | '
      'BEACON: ${beacon.id} | '
      'NODE: $newNodeId | '
      'RSSI: ${strongestRssi.toStringAsFixed(1)}',
    );

    // If a destination has already been selected,
    // recalculate route from the new current node.
    if (destinationNodeId != null) {
      _calculateRoute();
    }
  }

  void _calculateRoute() {
    if (config == null) {
      return;
    }

    if (currentNodeId == null) {
      return;
    }

    if (destinationNodeId == null) {
      return;
    }

    final path =
        _routeService.findShortestPath(
      config!,
      currentNodeId!,
      destinationNodeId!,
    );

    if (!mounted) return;

    setState(() {
      currentRoute = path;
    });

    debugPrint(
      'CURRENT NODE: $currentNodeId',
    );

    debugPrint(
      'DESTINATION NODE: '
      '$destinationNodeId',
    );

    debugPrint(
      'ROUTE: $path',
    );
  }

  Future<void> _searchDestination() async {
    if (config == null) {
      return;
    }

    final selectedDestination =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DestinationSearchPage(
          config: config!,
        ),
      ),
    );

    if (selectedDestination == null) {
      return;
    }

    final destinationNode =
        _configService
            .findNodeForDestination(
      config!,
      selectedDestination.id,
    );

    if (destinationNode == null) {
      debugPrint(
        'No node assigned to '
        '${selectedDestination.name}',
      );

      return;
    }

    destinationNodeId =
        destinationNode.id;

    debugPrint(
      'DESTINATION: '
      '${selectedDestination.name}',
    );

    debugPrint(
      'DESTINATION NODE: '
      '$destinationNodeId',
    );

    // Calculate route from CURRENT BLE NODE.
    _calculateRoute();
  }

  @override
  void dispose() {
    _bleSubscription?.cancel();
    _bleScanner.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Error:\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (config == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          config!.buildingName,
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 16,
            ),
            child: Center(
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(
                      shape: BoxShape.circle,
                      color: _bleScanning
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    _bleScanning
                        ? 'BLE'
                        : 'BLE OFF',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAP
          IndoorMap(
            config: config!,
            route: currentRoute,
            currentNodeId: currentNodeId,
          ),

          // SEARCH BUTTON
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: ElevatedButton.icon(
              onPressed:
                  _searchDestination,
              icon: const Icon(
                Icons.search,
              ),
              label: const Text(
                'Search Destination',
              ),
            ),
          ),

          // CURRENT POSITION CARD
          if (currentNodeId != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Current Position',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Node: $currentNodeId',
                            ),
                            if (currentBeaconId !=
                                null)
                              Text(
                                'Beacon: '
                                '$currentBeaconId',
                              ),
                          ],
                        ),
                      ),
                      if (currentRssi != null)
                        Text(
                          '${currentRssi!.toStringAsFixed(0)} dBm',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}