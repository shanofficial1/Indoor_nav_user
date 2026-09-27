import '../models/building_config.dart';

class RouteService {
  List<String> findShortestPath(
    BuildingConfig config,
    String startNodeId,
    String destinationNodeId,
  ) {
    if (startNodeId == destinationNodeId) {
      return [startNodeId];
    }

    final Map<String, List<String>> graph = {};

    // Create graph entries for every node.
    for (final node in config.nodes) {
      graph[node.id] = [];
    }

    // Edges are bidirectional.
    for (final edge in config.edges) {
      graph[edge.from]?.add(edge.to);
      graph[edge.to]?.add(edge.from);
    }

    final List<String> queue = [startNodeId];

    final Map<String, String?> previous = {
      startNodeId: null,
    };

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current == destinationNodeId) {
        break;
      }

      for (final neighbor in graph[current] ?? []) {
        if (!previous.containsKey(neighbor)) {
          previous[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    // Destination cannot be reached.
    if (!previous.containsKey(destinationNodeId)) {
      return [];
    }

    // Reconstruct path.
    final List<String> path = [];

    String? current = destinationNodeId;

    while (current != null) {
      path.add(current);
      current = previous[current];
    }

    return path.reversed.toList();
  }
}