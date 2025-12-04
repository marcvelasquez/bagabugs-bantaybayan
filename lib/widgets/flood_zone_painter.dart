import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

/// Flood zone data model
class FloodZone {
  final Offset center;
  final double radius;
  final double opacity;

  const FloodZone({
    required this.center,
    required this.radius,
    this.opacity = 0.4,
  });
}

/// Custom painter for flood zone heatmaps
class FloodZonePainter extends CustomPainter {
  final List<FloodZone> zones;

  FloodZonePainter({required this.zones});

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      // Create radial gradient for blur effect
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.floodZoneRed.withOpacity(zone.opacity),
                AppColors.floodZoneRed.withOpacity(zone.opacity * 0.5),
                AppColors.floodZoneRed.withOpacity(0),
              ],
              stops: const [0.0, 0.6, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(
                  size.width * zone.center.dx,
                  size.height * zone.center.dy,
                ),
                radius: zone.radius,
              ),
            );

      // Draw the flood zone circle
      canvas.drawCircle(
        Offset(size.width * zone.center.dx, size.height * zone.center.dy),
        zone.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FloodZonePainter oldDelegate) {
    return oldDelegate.zones != zones;
  }
}
