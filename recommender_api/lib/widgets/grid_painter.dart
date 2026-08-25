import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final bool isDark;

  GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Background Color
    final paintBg = Paint()
      ..color = isDark ? Colors.black : const Color(0xFFFFFDE7) // Light yellow paper
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    // Grid Lines
    final paintLines = Paint()
      ..color = isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue[200]!.withOpacity(0.5)
      ..strokeWidth = 1.0;

    const double gridSize = 40.0;

    // Draw vertical lines
    for (double i = 0; i <= size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paintLines);
    }

    // Draw horizontal lines
    for (double i = 0; i <= size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paintLines);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
