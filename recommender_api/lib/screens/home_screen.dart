import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomPaint(
        painter: GridPainter(isDark: isDark),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 64.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI STUDY SUITE",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blueAccent : Colors.blue[900],
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Your ultimate edutech workspace. Analyze your academic profile, chat dynamically with your course PDFs, and generate bite-sized study bundles tailored exactly to your available time.",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 20,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 64),
                Text(
                  "// EXPLORE MODES",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 24,
                    color: isDark ? Colors.blueAccent : Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _buildFeatureCard(
                      context: context,
                      title: "1. Recommender",
                      icon: Icons.psychology_outlined,
                      description: "Analyze your grades, attendance, and study habits to predict your academic trajectory and get targeted resources.",
                      isDark: isDark,
                      onTap: () => onNavigate(1),
                    ),
                    _buildFeatureCard(
                      context: context,
                      title: "2. Study Bundle",
                      icon: Icons.inventory_2_outlined,
                      description: "Only have 15 minutes? Enter your topic and we will generate a perfectly timed bundle of Flashcards, PYQs, and Videos.",
                      isDark: isDark,
                      onTap: () => onNavigate(2),
                    ),
                    _buildFeatureCard(
                      context: context,
                      title: "3. PDF Chat",
                      icon: Icons.chat_bubble_outline,
                      description: "Upload your lecture slides and seamlessly interrogate the material using our AI tutor.",
                      isDark: isDark,
                      onTap: () => onNavigate(3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String description,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.blueAccent.withOpacity(0.5) : Colors.blue.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.blueAccent.withOpacity(0.1) : Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: isDark ? Colors.blueAccent : Colors.blue[700]),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.shareTechMono(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.shareTechMono(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
