import 'package:flutter/material.dart';

/// BantayBayan Color Palette
/// Tactical Minimalist Design - System Dark/Light Mode Support
/// Dark Mode Colors: Consistent OKLCH palette
class AppColors {
  // Prevent instantiation
  AppColors._();

  // ===== DARK MODE COLORS (OKLCH Consistent) =====
  // oklch(20.8% 0.042 265.755) - Primary dark background (status bar, panels)
  static const Color darkBackgroundDeep = Color(0xFF2B2B42);
  
  // oklch(27.9% 0.041 260.031) - Dark
  static const Color darkBackgroundMid = Color(0xFF3A3A54);
  
  // oklch(37.2% 0.044 257.287) - Lightest (for elevated surfaces)
  static const Color darkBackgroundElevated = Color(0xFF4A4A66);

  // Dark Mode Text - White for contrast
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // White
  static const Color darkTextSecondary = Color(0xB3FFFFFF); // White 70% opacity
  static const Color darkTextTertiary = Color(0x80FFFFFF); // White 50% opacity

  // Dark Mode Borders - Light for visibility on dark backgrounds
  static const Color darkBorder = Color(0x4DFFFFFF); // White 30% opacity

  // ===== LIGHT MODE COLORS (Black & White) =====

  // Light Mode Backgrounds
  static const Color lightBackgroundPrimary = Color(0xFFFFFFFF); // Pure White
  static const Color lightBackgroundSecondary = Color(0xFFF5F5F5); // Off-White
  static const Color lightBackgroundTertiary = Color(0x33000000); // Black 20% opacity (glass)

  // Light Mode Text
  static const Color lightTextPrimary = Color(0xFF000000); // Pure Black
  static const Color lightTextSecondary = Color(0x99000000); // Black 60% opacity
  static const Color lightTextTertiary = Color(0x66000000); // Black 40% opacity

  // Light Mode Borders (for glass effect)
  static const Color lightBorderPrimary = Color(0x33000000); // Black 20% opacity
  static const Color lightBorderSecondary = Color(0x1A000000); // Black 10% opacity

  // ===== SHARED COLORS =====

  // Emergency Red - SOS elements, critical alerts
  static const Color emergencyRed = Color(0xFFFF3B30); // #FF3B30
  static const Color emergencyRedDark = Color(0xFFCC2F26);
  static const Color emergencyRedLight = Color(0xFFFF6B61);

  // High-Vis Amber - Alerts and accents
  static const Color amberDark = Color(0xFFFFCC00); // #FFCC00 for dark mode
  static const Color amberLight = Color(0xFFCC9900); // #CC9900 for light mode
  static const Color amberAccent = Color(0xFFFFDD44);

  // Status Colors
  static const Color statusCritical = Color(0xFFFF3B30); // Red
  static const Color statusWarning = Color(0xFFFFCC00); // Amber
  static const Color statusInfo = Color(0xFF64748B); // Gray
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  // Map Overlay Colors
  static const Color floodZoneRed = Color(0x66FF3B30); // Semi-transparent red
  static const Color locationMarker = Color(0xFFFF3B30); // Red marker
  static const Color locationMarkerBorder = Color(0xFFFFFFFF); // White border

  // Cluster Marker Severity Levels
  static const Color clusterHigh = Color(0xFFFF3B30); // Red
  static const Color clusterMedium = Color(0xFFFFCC00); // Amber
  static const Color clusterLow = Color(0xFF64748B); // Gray

  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000); // 10% black
  static const Color shadowMedium = Color(0x33000000); // 20% black
  static const Color shadowHeavy = Color(0x66000000); // 40% black

  // Glow Effects
  static const Color glowRed = Color(0x66FF3B30); // Red glow
  static const Color glowAmber = Color(0x66FFCC00); // Amber glow
  static const Color glowGray = Color(0x33000000); // Gray glow

  // ===== LEGACY ALIASES (for backward compatibility) =====
  // These map old color names to the new consistent theme
  static const Color backgroundDeep = darkBackgroundDeep;
  static const Color backgroundElevated = darkBackgroundElevated;
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Pure white
  static const Color textOnLight = Color(0xFF000000); // Black text
  static const Color textSecondary = Color(0xB3FFFFFF); // White 70% opacity
  static const Color slateGrey = Color(0xFF64748B); // Gray
  static const Color alertAmber = Color(0xFFFFCC00); // Amber
}
