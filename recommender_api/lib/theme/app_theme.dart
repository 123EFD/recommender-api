import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark Academia & Old-School Collegiate Color Palette
/// Reference: Space Cadet, Slate Gray, Tan, Coffee, Caput Mortuum, 
/// Antique Ivory, Burnt Umber, Deep Chestnut, Forest Moss, Oxford Brown, Charcoal Slate, Faded Gold.
class DarkAcademiaPalette {
  // Image 1: Space Cadet & Earthy Academia
  static const Color spaceCadet = Color(0xFF25344F);    // Rich Oxford Navy #25344F
  static const Color slateGray = Color(0xFF617891);     // Academic Slate #617891
  static const Color tan = Color(0xFFD5B893);           // Parchment Tan #D5B893
  static const Color coffee = Color(0xFF6F4D38);        // Leather Coffee #6F4D38
  static const Color caputMortuum = Color(0xFF632024);  // Vintage Seal / Caput Mortuum #632024

  // Image 2: Dark Academia 10-Color Palette
  static const Color antiqueIvory = Color(0xFFEDE8DC);  // Ancient Parchment #EDE8DC
  static const Color burntUmber = Color(0xFF8A4B2A);    // Burnt Umber #8A4B2A
  static const Color deepChestnut = Color(0xFF8B2C1F);  // Deep Chestnut #8B2C1F
  static const Color forestMoss = Color(0xFF3B3F2F);    // Forest Moss #3B3F2F
  static const Color oxfordBrown = Color(0xFF4B3B2A);   // Oxford Brown #4B3B2A
  static const Color charcoalSlate = Color(0xFF2C2E30); // Charcoal Slate #2C2E30
  static const Color vintageMaroon = Color(0xFF6B2E2F); // Vintage Maroon #6B2E2F
  static const Color mutedOlive = Color(0xFF85614B);    // Muted Olive / Bronze #85614B
  static const Color fadedGold = Color(0xFFBFA76F);     // Faded Gold Wax #BFA76F
  static const Color dustyTaupe = Color(0xFF9D8B7B);    // Dusty Taupe #9D8B7B
}

class GlassColors {
  final Color fillTopLeft;
  final Color fillBottomRight;
  final Color border;

  const GlassColors({
    required this.fillTopLeft,
    required this.fillBottomRight,
    required this.border,
  });

  factory GlassColors.forBrightness(Brightness brightness) {
    if (brightness == Brightness.light) {
      return GlassColors(
        fillTopLeft: Colors.white.withValues(alpha: 0.70),
        fillBottomRight: const Color(0xFFEDE8DC).withValues(alpha: 0.45),
        border: DarkAcademiaPalette.tan.withValues(alpha: 0.50), // Parchment Tan border
      );
    } else {
      return GlassColors(
        fillTopLeft: const Color(0xFF2C2E30).withValues(alpha: 0.70),
        fillBottomRight: const Color(0xFF1E2024).withValues(alpha: 0.50),
        border: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.30), // Faded Gold antique rim
      );
    }
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: DarkAcademiaPalette.oxfordBrown,
      displayColor: DarkAcademiaPalette.caputMortuum,
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFF7F5F0), // Warm Parchment
        onSurface: DarkAcademiaPalette.oxfordBrown,
        primary: DarkAcademiaPalette.caputMortuum, // Collegiate crimson seal
        onPrimary: DarkAcademiaPalette.antiqueIvory,
        secondary: DarkAcademiaPalette.spaceCadet,
        onSecondary: Colors.white,
        outline: DarkAcademiaPalette.tan,
        outlineVariant: DarkAcademiaPalette.dustyTaupe,
      ),
      scaffoldBackgroundColor: DarkAcademiaPalette.antiqueIvory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: DarkAcademiaPalette.spaceCadet),
        titleTextStyle: GoogleFonts.inter(
          color: DarkAcademiaPalette.spaceCadet,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF9F7F2),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: DarkAcademiaPalette.tan.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DarkAcademiaPalette.tan),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DarkAcademiaPalette.tan),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DarkAcademiaPalette.caputMortuum, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkAcademiaPalette.caputMortuum,
          foregroundColor: DarkAcademiaPalette.antiqueIvory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          shadowColor: DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: DarkAcademiaPalette.antiqueIvory,
      displayColor: DarkAcademiaPalette.fadedGold,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF232528), // Deep Charcoal
        onSurface: DarkAcademiaPalette.antiqueIvory,
        primary: DarkAcademiaPalette.fadedGold, // Antique Brass / Gold
        onPrimary: DarkAcademiaPalette.charcoalSlate,
        secondary: DarkAcademiaPalette.vintageMaroon,
        onSecondary: Colors.white,
        outline: DarkAcademiaPalette.oxfordBrown,
        outlineVariant: DarkAcademiaPalette.slateGray,
      ),
      scaffoldBackgroundColor: DarkAcademiaPalette.charcoalSlate,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: DarkAcademiaPalette.fadedGold),
        titleTextStyle: GoogleFonts.inter(
          color: DarkAcademiaPalette.fadedGold,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E2024),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2024),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DarkAcademiaPalette.oxfordBrown),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DarkAcademiaPalette.oxfordBrown),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DarkAcademiaPalette.fadedGold, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkAcademiaPalette.vintageMaroon,
          foregroundColor: DarkAcademiaPalette.antiqueIvory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          shadowColor: Colors.black45,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
