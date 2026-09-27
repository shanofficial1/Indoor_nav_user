import 'dart:math';
import 'dart:ui';

import '../models/building_config.dart';
import '../models/navigation_beacon.dart';
import 'package:flutter/foundation.dart';

class PositionEstimate {
  final Offset position;
  final String? nearestNodeId;

  final String? beaconAId;
  final String? beaconBId;

  final double? distanceA;
  final double? distanceB;

  PositionEstimate({
    required this.position,
    required this.nearestNodeId,
    this.beaconAId,
    this.beaconBId,
    this.distanceA,
    this.distanceB,
  });
}

class PositionEstimatorService {
  // Initial RSSI calibration values.
  //
  // Tx power = expected RSSI at approximately 1 meter.
  // n = indoor path-loss/environment factor.
  //
  // These values can be calibrated later using your actual ESP32 setup.
  final double txPower;
  final double pathLossExponent;

  PositionEstimatorService({
    this.txPower = -59.0,
    this.pathLossExponent = 2.0,
  });

  double rssiToDistance(double rssi) {
    return pow(
      10,
      (txPower - rssi) /
          (10 * pathLossExponent),
    ).toDouble();
  }

  PositionEstimate? estimate(
    BuildingConfig config,
    List<String> route,
    Map<String, double> filteredRssi,
  ) {
    if (route.isEmpty) {
      return null;
    }

    // Only use beacons that belong to nodes
    // currently present on the navigation route.
    final routeBeacons = config.beacons.where((beacon) {
      if (beacon.nodeId == null) {
        return false;
      }

      if (!route.contains(beacon.nodeId)) {
        return false;
      }

      return filteredRssi.containsKey(beacon.mac);
    }).toList();

    if (routeBeacons.isEmpty) {
      return null;
    }

    // Sort by strongest filtered RSSI.
    routeBeacons.sort((a, b) {
      final rssiA =
          filteredRssi[a.mac] ?? -999;

      final rssiB =
          filteredRssi[b.mac] ?? -999;

      return rssiB.compareTo(rssiA);
    });

    // If only one relevant beacon is available,
    // fall back to that beacon's position.
    if (routeBeacons.length == 1) {
      final beacon = routeBeacons.first;

      final nearestNode =
          _nearestNodeToPosition(
        config,
        route,
        beacon.position,
      );

      return PositionEstimate(
        position: beacon.position,
        nearestNodeId: nearestNode,
        beaconAId: beacon.id,
        distanceA:
            rssiToDistance(
          filteredRssi[beacon.mac]!,
        ),
      );
    }

    final beaconA = routeBeacons[0];
    final beaconB = routeBeacons[1];

    final rssiA = filteredRssi[beaconA.mac]!;
    final rssiB = filteredRssi[beaconB.mac]!;

    final distanceA =
        rssiToDistance(rssiA);

    final distanceB =
        rssiToDistance(rssiB);

    debugPosition(
      beaconA,
      beaconB,
      rssiA,
      rssiB,
      distanceA,
      distanceB,
    );

    final nodeAIndex =
        route.indexOf(beaconA.nodeId!);

    final nodeBIndex =
        route.indexOf(beaconB.nodeId!);

    if (nodeAIndex == -1 ||
        nodeBIndex == -1 ||
        nodeAIndex == nodeBIndex) {
      return null;
    }

    final startIndex =
        min(nodeAIndex, nodeBIndex);

    final endIndex =
        max(nodeAIndex, nodeBIndex);

    final routePoints = <Offset>[];

    for (int i = startIndex;
        i <= endIndex;
        i++) {
      final node = config.nodes.firstWhere(
        (node) => node.id == route[i],
      );

      routePoints.add(node.position);
    }

    if (routePoints.length < 2) {
      return null;
    }

    final totalRouteLength =
        _polylineLength(routePoints);

    if (totalRouteLength <= 0) {
      return null;
    }

    /*
      Example:

      B1                         B2
      ●--------------------------●
          30%       ↑
                   USER

      distance from B1 = 3m
      distance from B2 = 7m

      ratio = 3 / (3 + 7)
            = 0.30

      Therefore user is approximately
      30% along the route section.
    */

    double ratio =
        distanceA /
        (distanceA + distanceB);

    ratio = ratio.clamp(0.0, 1.0);

    final position =
        _pointAlongPolyline(
      routePoints,
      totalRouteLength,
      ratio,
    );

    final nearestNode =
        _nearestNodeToPosition(
      config,
      route,
      position,
    );

    return PositionEstimate(
      position: position,
      nearestNodeId: nearestNode,
      beaconAId: beaconA.id,
      beaconBId: beaconB.id,
      distanceA: distanceA,
      distanceB: distanceB,
    );
  }

  double _polylineLength(
    List<Offset> points,
  ) {
    double total = 0;

    for (int i = 0;
        i < points.length - 1;
        i++) {
      total +=
          (points[i + 1] - points[i]).distance;
    }

    return total;
  }

  Offset _pointAlongPolyline(
    List<Offset> points,
    double totalLength,
    double ratio,
  ) {
    final targetDistance =
        totalLength * ratio;

    double travelled = 0;

    for (int i = 0;
        i < points.length - 1;
        i++) {
      final start = points[i];
      final end = points[i + 1];

      final segmentLength =
          (end - start).distance;

      if (travelled + segmentLength >=
          targetDistance) {
        final remaining =
            targetDistance - travelled;

        final segmentRatio =
            segmentLength == 0
                ? 0
                : remaining / segmentLength;

        return Offset(
          start.dx +
              (end.dx - start.dx) *
                  segmentRatio,
          start.dy +
              (end.dy - start.dy) *
                  segmentRatio,
        );
      }

      travelled += segmentLength;
    }

    return points.last;
  }

  String? _nearestNodeToPosition(
    BuildingConfig config,
    List<String> route,
    Offset position,
  ) {
    String? nearestId;
    double nearestDistance =
        double.infinity;

    for (final nodeId in route) {
      final matchingNodes =
          config.nodes.where(
        (node) => node.id == nodeId,
      );

      if (matchingNodes.isEmpty) {
        continue;
      }

      final node =
          matchingNodes.first;

      final distance =
          (node.position - position)
              .distance;

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = node.id;
      }
    }

    return nearestId;
  }

  void debugPosition(
    NavigationBeacon beaconA,
    NavigationBeacon beaconB,
    double rssiA,
    double rssiB,
    double distanceA,
    double distanceB,
  ) {
    debugPrint(
      'POSITION ESTIMATION | '
      '${beaconA.id} RSSI=${rssiA.toStringAsFixed(1)} '
      'DIST=${distanceA.toStringAsFixed(2)}m | '
      '${beaconB.id} RSSI=${rssiB.toStringAsFixed(1)} '
      'DIST=${distanceB.toStringAsFixed(2)}m',
    );
  }
}