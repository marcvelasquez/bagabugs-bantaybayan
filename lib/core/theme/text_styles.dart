import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// BantayBayan Typography System
/// Large, legible fonts for high-stress situations
class AppTextStyles {
  // Prevent instantiation
  AppTextStyles._();

  // Font Families
  static const String primaryFont = 'Montserrat';
  static const String secondaryFont = 'Montserrat';

  // Display Styles - Extra Large for Critical Information
  static TextStyle displayLarge = GoogleFonts.montserrat(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium = GoogleFonts.montserrat(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.25,
  );

  static TextStyle displaySmall = GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // Headline Styles - For Section Headers
  static TextStyle headlineLarge = GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  static TextStyle headlineMedium = GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static TextStyle headlineSmall = GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body Styles - For Main Content
  static TextStyle bodyLarge = GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  // Label Styles - For Buttons and Small Text
  static TextStyle labelLarge = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static TextStyle labelMedium = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  // Special Styles for Emergency Elements
  static TextStyle sosButton = GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 2.0,
  );

  static TextStyle emergencyBanner = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  static TextStyle clusterNumber = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    height: 1.0,
  );

  // GPS Coordinates Style
  static TextStyle coordinates = GoogleFonts.robotoMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // Helper method to add shadow to any text style
  static TextStyle withShadow(
    TextStyle style, {
    required Color shadowColor,
    Offset offset = const Offset(0, 2),
    double blurRadius = 4,
  }) {
    return style.copyWith(
      shadows: [
        Shadow(color: shadowColor, offset: offset, blurRadius: blurRadius),
      ],
    );
  }

  // Helper method to change color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }
}
