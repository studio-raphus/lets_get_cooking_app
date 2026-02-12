import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class AppTheme {
  // Modern Culinary Palette (Terra Cotta & Basil)
  static const Color seedColor = Color(0xFF2D6A4F); // Deep Forest Green
  static const Color secondarySeed = Color(0xFFE0B97F); // Warm Wheat/Bread

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      secondary: secondarySeed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFF9F0), // Warm tinted surface
    );

    // Base text theme
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,

      // Modern Typography - Applied Primary Color to All Text
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 57),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 45),
        displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 36),
        headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 32),
        headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 28),
        titleLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 22),
        titleMedium: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: GoogleFonts.dmSans(fontSize: 16),
        bodyMedium: GoogleFonts.dmSans(fontSize: 14),
      ).apply(
        bodyColor: seedColor,
        displayColor: seedColor,
      ),

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary, // Primary Color Background
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Dominant Primary Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: seedColor, // Red background
        indicatorColor: secondarySeed, // Cream indicator
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: seedColor); // Red icon on Cream indicator
          }
          return const IconThemeData(color: Colors.white); // White icon on Red background
        }),
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// =============================================================================
// SHADER PAINTER (Mesh Gradient)
// =============================================================================
class MeshGradientPainter extends CustomPainter {
  final Animation<double> animation;
  final ColorScheme colors;

  MeshGradientPainter({required this.animation, required this.colors}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    // Orb 1: Primary (Moving)
    paint.color = colors.primary.withOpacity(0.6); // Increased opacity for dominance
    canvas.drawCircle(
      Offset(
        size.width * (0.3 + 0.2 * math.sin(t * 2 * math.pi)),
        size.height * (0.2 + 0.1 * math.cos(t * 2 * math.pi)),
      ),
      size.width * 0.6,
      paint,
    );

    // Orb 2: Secondary (Moving opposite)
    paint.color = colors.secondaryContainer.withOpacity(0.5);
    canvas.drawCircle(
      Offset(
        size.width * (0.7 - 0.2 * math.sin(t * 2 * math.pi)),
        size.height * (0.4 + 0.15 * math.cos(t * 2 * math.pi + 1)),
      ),
      size.width * 0.5,
      paint,
    );

    // Orb 3: Tertiary (Static anchor)
    paint.color = colors.tertiaryContainer.withOpacity(0.3);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.8),
      size.width * 0.7,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) => true;
}