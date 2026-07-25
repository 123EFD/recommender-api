import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        fillTopLeft: Colors.white.withValues(alpha: 0.12),
        fillBottomRight: Colors.white.withValues(alpha: 0.12 * 0.4),
        border: Colors.white.withValues(alpha: 0.2),
      );
    } else {
      return GlassColors(
        fillTopLeft: Colors.white.withValues(alpha: 0.08),
        fillBottomRight: Colors.white.withValues(alpha: 0.08 * 0.4),
        border: Colors.white.withValues(alpha: 0.1),
      );
    }
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: const Color(0xff18181b), // zinc-900
      displayColor: const Color(0xff18181b),
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: Color(0xfffafafa), // zinc-50
        onSurface: Color(0xff18181b), // zinc-900
        primary: Color(0xff2563eb), // blue-600
        onPrimary: Colors.white,
        outline: Color(0xffe4e4e7), // zinc-200
        outlineVariant: Color(0xffd4d4d8), // zinc-300
      ),
      scaffoldBackgroundColor: const Color(0xfffafafa),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xff18181b)),
        titleTextStyle: TextStyle(color: Color(0xff18181b), fontSize: 20, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xffe4e4e7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffd4d4d8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffd4d4d8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff2563eb), width: 2), // blue ring
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff2563eb),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: const Color(0xfffafafa), // zinc-50
      displayColor: const Color(0xfffafafa),
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: Color(0xff09090b), // zinc-950
        onSurface: Color(0xfffafafa), // zinc-50
        primary: Color(0xff3b82f6), // blue-500
        onPrimary: Colors.white,
        outline: Color(0xff27272a), // zinc-800
        outlineVariant: Color(0xff3f3f46), // zinc-700
      ),
      scaffoldBackgroundColor: const Color(0xff09090b),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xfffafafa)),
        titleTextStyle: TextStyle(color: Color(0xfffafafa), fontSize: 20, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xff18181b), // zinc-900
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xff27272a)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff3f3f46)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff3f3f46)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff3b82f6), width: 2), // blue ring
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff3b82f6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
