import 'dart:ui';

import '../models/building_config.dart';

class PositionService {
  String? currentBeaconId;
  String? currentNodeId;
  Offset? currentPosition;

  void update(
    BuildingConfig config,
    Map<String, double> filteredRssi,
  ) {
    if (filteredRssi.isEmpty) {
      return;
    }

    String? strongestMac;
    double? strongestRssi;

    for (final entry in filteredRssi.entries) {
      if (strongestRssi == null ||
          entry.value > strongestRssi) {
        strongestMac = entry.key;
        strongestRssi = entry.value;
      }
    }

    if (strongestMac == null) {
      return;
    }

    final beacon = config.beacons.where(
      (b) =>
          b.mac.toUpperCase() ==
          strongestMac!.toUpperCase(),
    );

    if (beacon.isEmpty) {
      return;
    }

    final selectedBeacon = beacon.first;

    currentBeaconId = selectedBeacon.id;
    currentNodeId = selectedBeacon.nodeId;
    currentPosition = selectedBeacon.position;
  }

  void clear() {
    currentBeaconId = null;
    currentNodeId = null;
    currentPosition = null;
  }
}