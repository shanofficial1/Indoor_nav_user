import 'package:flutter/material.dart';

import '../models/building_config.dart';
import 'navigation_map_painter.dart';

class IndoorMap extends StatelessWidget {
  final BuildingConfig config;
  final List<String> route;
final String? currentNodeId;
const IndoorMap({
  super.key,
  required this.config,
  this.route = const [],
  this.currentNodeId,
});

  // Actual floor-plan PNG dimensions.
  static const double imageWidth = 1290.0;
  static const double imageHeight = 1219.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the complete available width.
          final double displayWidth = constraints.maxWidth;

          // Keep the REAL PNG aspect ratio.
          final double displayHeight =
              displayWidth * (imageHeight / imageWidth);

          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            boundaryMargin: EdgeInsets.zero,
            constrained: false,

            child: SizedBox(
              width: displayWidth,
              height: displayHeight,

              child: Stack(
                children: [
                  // Actual PNG.
                  Image.asset(
                    config.mapImage,
                    width: displayWidth,
                    height: displayHeight,
                    fit: BoxFit.fill,
                  ),

                  // Nodes + paths.
                  CustomPaint(
                    size: Size(
                      displayWidth,
                      displayHeight,
                    ),
                   painter: NavigationMapPainter(
  config: config,
  route: route,
  currentNodeId: currentNodeId,
),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}