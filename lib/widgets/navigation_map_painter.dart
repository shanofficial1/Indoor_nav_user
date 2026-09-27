import 'package:flutter/material.dart';

import '../models/building_config.dart';


class NavigationMapPainter extends CustomPainter {
  final BuildingConfig config;
  final List<String> route;
final String? currentNodeId;
final Offset? currentPosition;
NavigationMapPainter({
  required this.config,
  required this.route,
  this.currentNodeId,
  this.currentPosition,
});

  @override
  void paint(Canvas canvas, Size size) {
    const double jsonWidth = 3000.0;
    const double jsonHeight = 3000.0;

    final double scaleX = size.width / jsonWidth;
    final double scaleY = size.height / jsonHeight;

    final pathPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final nodeBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    Offset convert(Offset position) {
      return Offset(
        position.dx * scaleX,
        position.dy * scaleY,
      );
    }

    // Draw only the calculated route.
    for (int i = 0; i < route.length - 1; i++) {
      final fromNode = config.nodes.firstWhere(
        (node) => node.id == route[i],
      );

      final toNode = config.nodes.firstWhere(
        (node) => node.id == route[i + 1],
      );

      final from = convert(fromNode.position);
      final to = convert(toNode.position);

      canvas.drawLine(from, to, pathPaint);
    }

    // Draw nodes.
    for (final node in config.nodes) {
      final position = convert(node.position);

      canvas.drawCircle(
        position,
        2,
        nodePaint,
      );

      canvas.drawCircle(
        position,
        2,
        nodeBorderPaint,
      );
    }
if (currentPosition != null) {
  final x =
      currentPosition!.dx * scaleX;

  final y =
      currentPosition!.dy * scaleY;

  final point =
      Offset(x, y);


  final bluePaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;


  canvas.drawCircle(
    point,
    6,
    bluePaint,
  );
}
  }

  @override
  bool shouldRepaint(
    covariant NavigationMapPainter oldDelegate,
  ) {
    return oldDelegate.config != config ||
        oldDelegate.route != route;
  }
}