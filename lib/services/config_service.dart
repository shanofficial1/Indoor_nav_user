import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/building_config.dart';

import '../models/navigation_node.dart';

class ConfigService {
  static const String configPath =
      'assets/config/building_config.json';
NavigationNode? findNodeForDestination(
  BuildingConfig config,
  String roomId,
) {
  for (final node in config.nodes) {
    if (node.roomIds.contains(roomId)) {
      return node;
    }
  }

  return null;
}
  Future<BuildingConfig> loadConfig() async {
    final jsonString = await rootBundle.loadString(configPath);

    final Map<String, dynamic> jsonData =
        jsonDecode(jsonString) as Map<String, dynamic>;

    return BuildingConfig.fromJson(jsonData);
  }

  
}