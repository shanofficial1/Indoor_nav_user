import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/building_config.dart';

class GraphPositionEstimate {
  final Offset position;
  final String? nearestNodeId;

  final String? beaconAId;
  final String? beaconBId;

  final double distanceFromBeaconA;
  final double distanceFromBeaconB;

  final double routeDistance;

  GraphPositionEstimate({
    required this.position,
    required this.nearestNodeId,
    required this.beaconAId,
    required this.beaconBId,
    required this.distanceFromBeaconA,
    required this.distanceFromBeaconB,
    required this.routeDistance,
  });
}

class GraphPositionService {
  final double txPower;
  final double pathLossExponent;

  GraphPositionService({
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

  /*
  ============================================================
  PUBLIC METHOD
  ============================================================

  If route is supplied:

      user position -> current navigation route

  If route is empty:

      user position -> complete building graph

  In BOTH cases the final position is ALWAYS
  projected onto an actual graph EDGE.
  */

  GraphPositionEstimate? calculate(
    BuildingConfig config,
    List<String> route,
    Map<String, double> filteredRssi,
  ) {
    final allowedEdges =
        _buildAllowedEdges(
      config,
      route,
    );

    if (allowedEdges.isEmpty) {
      return null;
    }

    /*
    ------------------------------------------------------------
    Find beacons that are relevant to the allowed graph.
    ------------------------------------------------------------
    */

    final relevantBeacons =
        config.beacons.where((beacon) {
      if (beacon.nodeId == null) {
        return false;
      }

      if (route.isNotEmpty &&
          !route.contains(beacon.nodeId)) {
        return false;
      }

      return filteredRssi.containsKey(
        beacon.mac,
      );
    }).toList();

    if (relevantBeacons.isEmpty) {
      return null;
    }

    /*
    ------------------------------------------------------------
    Sort by strongest RSSI.
    ------------------------------------------------------------
    */

    relevantBeacons.sort((a, b) {
      final rssiA =
          filteredRssi[a.mac] ?? -999;

      final rssiB =
          filteredRssi[b.mac] ?? -999;

      return rssiB.compareTo(rssiA);
    });

    final beaconA =
        relevantBeacons.first;

    final rssiA =
        filteredRssi[beaconA.mac]!;

    final distanceA =
        rssiToDistance(rssiA);

    /*
    ============================================================
    ONE BEACON
    ============================================================

    IMPORTANT:

    We DO NOT use beacon.position directly.

    We project the beacon position onto the graph.
    */

    if (relevantBeacons.length == 1) {
      final projection =
          _nearestPointOnGraph(
        beaconA.position,
        allowedEdges,
      );

      if (projection == null) {
        return null;
      }

      final nearestNodeId =
          _nearestNode(
        config,
        route,
        projection.point,
      );

      debugPrint(
        'GRAPH POSITION | '
        'ONE BEACON | '
        'B=${beaconA.id} '
        'RSSI=${rssiA.toStringAsFixed(1)} | '
        'RAW=('
        '${beaconA.position.dx.toStringAsFixed(1)},'
        '${beaconA.position.dy.toStringAsFixed(1)}'
        ') | '
        'SNAPPED=('
        '${projection.point.dx.toStringAsFixed(1)},'
        '${projection.point.dy.toStringAsFixed(1)}'
        ') | '
        'NODE=$nearestNodeId',
      );

      return GraphPositionEstimate(
        position: projection.point,
        nearestNodeId: nearestNodeId,
        beaconAId: beaconA.id,
        beaconBId: null,
        distanceFromBeaconA: distanceA,
        distanceFromBeaconB: 0,
        routeDistance:
    projection.distanceAlongGraph /
    (config.mapWidth / config.mapLengthMeters),
      );
    }

    /*
    ============================================================
    TWO BEACONS
    ============================================================
    */

    final beaconB =
        relevantBeacons[1];

    final rssiB =
        filteredRssi[beaconB.mac]!;

    final distanceB =
        rssiToDistance(rssiB);

    /*
    ------------------------------------------------------------
    Weighted raw estimate.

    Stronger beacon gets more influence.
    ------------------------------------------------------------
    */

    final weightA =
        1.0 /
            max(
              distanceA * distanceA,
              0.01,
            );

    final weightB =
        1.0 /
            max(
              distanceB * distanceB,
              0.01,
            );

    final totalWeight =
        weightA + weightB;

    final rawX =
        ((beaconA.position.dx *
                    weightA) +
                (beaconB.position.dx *
                    weightB)) /
            totalWeight;

    final rawY =
        ((beaconA.position.dy *
                    weightA) +
                (beaconB.position.dy *
                    weightB)) /
            totalWeight;

    final rawPosition =
        Offset(
      rawX,
      rawY,
    );

    /*
    ------------------------------------------------------------
    HARD CONSTRAINT

    Raw position is NEVER returned.

    It is projected onto an actual graph edge.
    ------------------------------------------------------------
    */

    final projection =
        _nearestPointOnGraph(
      rawPosition,
      allowedEdges,
    );

    if (projection == null) {
      return null;
    }

    final nearestNodeId =
        _nearestNode(
      config,
      route,
      projection.point,
    );

    debugPrint(
      'GRAPH POSITION | '
      'B1=${beaconA.id} '
      'RSSI=${rssiA.toStringAsFixed(1)} '
      'D=${distanceA.toStringAsFixed(2)}m | '
      'B2=${beaconB.id} '
      'RSSI=${rssiB.toStringAsFixed(1)} '
      'D=${distanceB.toStringAsFixed(2)}m | '
      'RAW=('
      '${rawPosition.dx.toStringAsFixed(1)},'
      '${rawPosition.dy.toStringAsFixed(1)}'
      ') | '
      'SNAPPED=('
      '${projection.point.dx.toStringAsFixed(1)},'
      '${projection.point.dy.toStringAsFixed(1)}'
      ') | '
      'NODE=$nearestNodeId',
    );

    return GraphPositionEstimate(
      position: projection.point,
      nearestNodeId: nearestNodeId,
      beaconAId: beaconA.id,
      beaconBId: beaconB.id,
      distanceFromBeaconA: distanceA,
      distanceFromBeaconB: distanceB,
      routeDistance:
          projection.distanceAlongGraph /
          (config.mapWidth / config.mapLengthMeters),
    );
  }

  /*
  ============================================================
  BUILD THE WALKABLE GRAPH
  ============================================================

  If route is empty:

      use ALL edges.

  If route exists:

      use ONLY edges connecting consecutive
      nodes in the current route.
  */


Offset constrainPositionToGraph(
  BuildingConfig config,
  List<String> route,
  Offset position,
) {
  final allowedEdges = _buildAllowedEdges(
    config,
    route,
  );

  if (allowedEdges.isEmpty) {
    return position;
  }

  final projection = _nearestPointOnGraph(
    position,
    allowedEdges,
  );

  return projection?.point ?? position;
}

double calculateRouteLength(
  BuildingConfig config,
  List<String> route,
) {
  if (route.length < 2) {
    return 0;
  }

  double totalDistance = 0;

  for (int i = 0; i < route.length - 1; i++) {
    final fromId = route[i];
    final toId = route[i + 1];

    final fromNodes = config.nodes.where(
      (node) => node.id == fromId,
    );

    final toNodes = config.nodes.where(
      (node) => node.id == toId,
    );

    if (fromNodes.isEmpty || toNodes.isEmpty) {
      continue;
    }
    final pixelsPerMeter =
    config.mapWidth / config.mapLengthMeters;


   totalDistance +=
    (toNodes.first.position -
            fromNodes.first.position)
        .distance /
    pixelsPerMeter;
  }

  return totalDistance;
}


  List<_GraphEdge> _buildAllowedEdges(
    BuildingConfig config,
    List<String> route,
  ) {
    final edges = <_GraphEdge>[];

    /*
    ------------------------------------------------------------
    Navigation route exists
    ------------------------------------------------------------
    */

    if (route.length >= 2) {
      for (int i = 0;
          i < route.length - 1;
          i++) {
        final fromId =
            route[i];

        final toId =
            route[i + 1];

        final fromNodes =
            config.nodes.where(
          (node) => node.id == fromId,
        );

        final toNodes =
            config.nodes.where(
          (node) => node.id == toId,
        );

        if (fromNodes.isEmpty ||
            toNodes.isEmpty) {
          continue;
        }

        edges.add(
          _GraphEdge(
            from: fromNodes.first.position,
            to: toNodes.first.position,
            fromId: fromId,
            toId: toId,
          ),
        );
      }

      return edges;
    }

    /*
    ------------------------------------------------------------
    NO NAVIGATION

    Use EVERY edge in the building.
    ------------------------------------------------------------
    */

    for (final edge in config.edges) {
      final fromNodes =
          config.nodes.where(
        (node) => node.id == edge.from,
      );

      final toNodes =
          config.nodes.where(
        (node) => node.id == edge.to,
      );

      if (fromNodes.isEmpty ||
          toNodes.isEmpty) {
        continue;
      }

      edges.add(
        _GraphEdge(
          from: fromNodes.first.position,
          to: toNodes.first.position,
          fromId: edge.from,
          toId: edge.to,
        ),
      );
    }

    return edges;
  }

  /*
  ============================================================
  FIND THE CLOSEST POINT ON ANY GRAPH EDGE
  ============================================================
  */

  _GraphProjection? _nearestPointOnGraph(
    Offset position,
    List<_GraphEdge> edges,
  ) {
    _GraphProjection? best;

    for (final edge in edges) {
      final projection =
          _projectPointToSegment(
        position,
        edge,
      );

      if (best == null ||
          projection.distance <
              best.distance) {
        best = projection;
      }
    }

    return best;
  }

  /*
  ============================================================
  PROJECT POINT ONTO ONE EDGE
  ============================================================
  */

  _GraphProjection _projectPointToSegment(
    Offset point,
    _GraphEdge edge,
  ) {
    final dx =
        edge.to.dx -
            edge.from.dx;

    final dy =
        edge.to.dy -
            edge.from.dy;

    final lengthSquared =
        dx * dx +
            dy * dy;

    if (lengthSquared == 0) {
      return _GraphProjection(
        point: edge.from,
        distance:
            (point - edge.from).distance,
        distanceAlongGraph: 0,
        edgeFromId: edge.fromId,
        edgeToId: edge.toId,
      );
    }

    /*
    ------------------------------------------------------------
    Calculate projection ratio.
    ------------------------------------------------------------
    */

    double t =
        ((point.dx -
                    edge.from.dx) *
                dx +
            (point.dy -
                    edge.from.dy) *
                dy) /
        lengthSquared;

    /*
    ------------------------------------------------------------
    HARD LIMIT

    The user can NEVER exist outside this edge.

    0.0 = first node
    1.0 = second node
    ------------------------------------------------------------
    */

    t = t.clamp(
      0.0,
      1.0,
    );

    final projected =
        Offset(
      edge.from.dx +
          dx * t,
      edge.from.dy +
          dy * t,
    );

    final edgeLength =
        (edge.to -
                edge.from)
            .distance;




return _GraphProjection(
  point: projected,
  distance:
      (point - projected).distance,
  distanceAlongGraph:
      edgeLength * t,
  edgeFromId: edge.fromId,
  edgeToId: edge.toId,
);
  }

  /*
  ============================================================
  FIND NEAREST NODE
  ============================================================
  */

  String? _nearestNode(
    BuildingConfig config,
    List<String> route,
    Offset position,
  ) {
    String? nearestId;

    double nearestDistance =
        double.infinity;

    Iterable nodes;

    if (route.isNotEmpty) {
      nodes = config.nodes.where(
        (node) =>
            route.contains(node.id),
      );
    } else {
      nodes = config.nodes;
    }

    for (final node in nodes) {
      final distance =
          (node.position -
                  position)
              .distance;

      if (distance <
          nearestDistance) {
        nearestDistance =
            distance;

        nearestId =
            node.id;
      }
    }

    return nearestId;
  }
}

/*
==============================================================
GRAPH EDGE
==============================================================
*/

class _GraphEdge {
  final Offset from;
  final Offset to;

  final String fromId;
  final String toId;

  _GraphEdge({
    required this.from,
    required this.to,
    required this.fromId,
    required this.toId,
  });
}

/*
==============================================================
GRAPH PROJECTION
==============================================================
*/

class _GraphProjection {
  final Offset point;

  final double distance;

  final double distanceAlongGraph;

  final String edgeFromId;
  final String edgeToId;

  _GraphProjection({
    required this.point,
    required this.distance,
    required this.distanceAlongGraph,
    required this.edgeFromId,
    required this.edgeToId,
  });
}