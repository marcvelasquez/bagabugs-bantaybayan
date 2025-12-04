import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

/// Custom painter for street grid pattern overlay on map
class StreetGridPainter extends CustomPainter {
  final bool isDarkMode;
  final double gridSize;

  StreetGridPainter({required this.isDarkMode, this.gridSize = 80.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? AppColors.darkBorder.withOpacity(0.3)
          : AppColors.lightBorderPrimary.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant StreetGridPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.gridSize != gridSize;
  }
}
