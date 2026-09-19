import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final bool isDark;

  GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Academia Background Color: Antique Ivory in light mode, Charcoal Slate in dark mode
    final paintBg = Paint()
      ..color = isDark ? const Color(0xFF1E2024) : const Color(0xFFEDE8DC)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    // 2. Archival Drafting Grid Lines
    final paintLines = Paint()
      ..color = isDark 
          ? const Color(0xFFBFA76F).withValues(alpha: 0.07) // Faded Gold in dark mode
          : const Color(0xFF6F4D38).withValues(alpha: 0.10) // Coffee / Burnt Umber in light mode
      ..strokeWidth = 0.8;

    const double gridSize = 36.0;

    // Draw vertical lines
    for (double i = 0; i <= size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paintLines);
    }

    // Draw horizontal lines
    for (double i = 0; i <= size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paintLines);
    }

    // 3. Subtle intersection dots for archival manuscript texture
    final paintDots = Paint()
      ..color = isDark 
          ? const Color(0xFFBFA76F).withValues(alpha: 0.18)
          : const Color(0xFF4B3B2A).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawCircle(Offset(x, y), 1.0, paintDots);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
