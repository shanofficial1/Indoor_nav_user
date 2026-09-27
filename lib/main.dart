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


import 'services/graph_position_service.dart';

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
  final GraphPositionService _graphPositionService =
    GraphPositionService(
  txPower: -59.0,
  pathLossExponent: 2.0,
);




  StreamSubscription<List<ScanResult>>?
      _bleSubscription;

  BuildingConfig? config;

  String? error;

  String? currentNodeId;
String? currentBeaconId;
double? currentRssi;
Offset? currentPosition;

String? positionBeaconA;
String? positionBeaconB;

double? distanceFromBeaconA;
double? distanceFromBeaconB;

  // Destination node.
String? destinationNodeId;
String? destinationName;
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

  // ---------------------------------------------
  // 1. Collect filtered RSSI from configured
  //    beacons
  // ---------------------------------------------

  for (final result in results) {
    final mac = result.device.remoteId.str;

    final configuredBeacon =
        appConfig.beacons.where(
      (beacon) =>
          beacon.mac.toUpperCase() ==
          mac.toUpperCase(),
    );

    if (configuredBeacon.isEmpty) {
      continue;
    }

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
      'FILTERED: '
      '${filtered.toStringAsFixed(1)}',
    );
  }

  if (_filteredRssi.isEmpty) {
    return;
  }

  // ---------------------------------------------
  // 2. NAVIGATION MODE
  // ---------------------------------------------

/*
==============================================================
GRAPH POSITIONING

This ALWAYS runs.

No destination is required.

If destination exists:
    position is constrained to navigation route.

If destination does not exist:
    position is constrained to the complete building graph.
==============================================================
*/

final estimate =
    _graphPositionService.calculate(
  appConfig,
  destinationNodeId != null
      ? currentRoute
      : const [],
  _filteredRssi,
);

if (estimate != null) {
  final oldNodeId =
      currentNodeId;

  if (!mounted) {
    return;
  }

  setState(() {
    currentPosition =
        estimate.position;

    currentNodeId =
        estimate.nearestNodeId;

    currentBeaconId =
        estimate.beaconAId;

    currentRssi =
        _filteredRssi[
          appConfig.beacons
              .firstWhere(
                (beacon) =>
                    beacon.id ==
                    estimate.beaconAId,
              )
              .mac
        ];
  });

  debugPrint(
    'FINAL USER POSITION | '
    'X=${estimate.position.dx.toStringAsFixed(1)} '
    'Y=${estimate.position.dy.toStringAsFixed(1)} '
    'NODE=${estimate.nearestNodeId}',
  );

  /*
    If the user crossed into another graph node
    while navigating, update the remaining route.
  */
  if (destinationNodeId != null &&
      estimate.nearestNodeId != null &&
      estimate.nearestNodeId != oldNodeId) {
    _calculateRoute();
  }

  return;
}

  // ---------------------------------------------
  // 3. NO NAVIGATION
  //
  // Keep the old strongest-beacon behavior.
  // ---------------------------------------------

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

  if (strongestMac == null ||
      strongestRssi == null) {
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

  final newNodeId =
      beacon.nodeId;

  if (newNodeId == null) {
    return;
  }

  if (!mounted) {
    return;
  }



  debugPrint(
    'CURRENT POSITION | '
    'BEACON: ${beacon.id} | '
    'NODE: $newNodeId | '
    'RSSI: '
    '${strongestRssi.toStringAsFixed(1)}',
  );

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
destinationName = selectedDestination.name;
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
  void _stopNavigation() {
  if (!mounted) return;

  setState(() {
    destinationNodeId = null;
    destinationName = null;
    currentRoute = [];
  });

  debugPrint('NAVIGATION STOPPED');
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
  currentPosition: currentPosition,
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
        padding: const EdgeInsets.all(12),
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
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Position',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Node: $currentNodeId',
                  ),
                  if (currentBeaconId != null)
                    Text(
                      'Beacon: $currentBeaconId',
                    ),
                  if (destinationName != null)
                    Text(
                      'Destination: $destinationName',
                    ),
                 if (currentRoute.isNotEmpty &&
    currentRoute.length == 1)
  const Text(
    '🏁 You have arrived!',
    style: TextStyle(
      color: Colors.green,
      fontWeight: FontWeight.bold,
    ),
  )
else if (currentRoute.isNotEmpty)
  Text(
    '${currentRoute.length - 1} nodes remaining',
  ),
                ],
              ),
            ),
            IconButton(
  onPressed: _stopNavigation,
  icon: const Icon(Icons.close),
  tooltip: 'Stop Navigation',
),
            if (currentRssi != null)
              Text(
                '${currentRssi!.toStringAsFixed(0)} dBm',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
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