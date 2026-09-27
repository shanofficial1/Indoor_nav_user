import 'dart:ui';

class NavigationBeacon {
  final String id;
  final String name;
  final String mac;
  final Offset position;
  final double range;
  final String? nodeId;

  NavigationBeacon({
    required this.id,
    required this.name,
    required this.mac,
    required this.position,
    required this.range,
    required this.nodeId,
  });

  factory NavigationBeacon.fromJson(Map<String, dynamic> json) {
    return NavigationBeacon(
      id: json['id'] as String,
      name: json['name'] as String,
      mac: json['mac'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      range: (json['range'] as num).toDouble(),
      nodeId: json['nodeId'] as String?,
    );
  }
}