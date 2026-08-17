import 'package:flutter/material.dart';
import 'package:animated_flash_cards/animated_flash_cards.dart';
import '../models/resource_item.dart';

class FlashcardDeckWidget extends StatelessWidget {
  final List<ResourceItem> items;

  const FlashcardDeckWidget({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text("No flashcards available."));
    }

    List<Widget> topPages = [];
    List<Widget> bottomPages = [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (var item in items) {
      String frontText = "";
      String backText = "";

      try {
        String cleanContent = item.content
            .replaceAll('<br>', '\n')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>');

        if (cleanContent.contains('**Answer:**')) {
          frontText = cleanContent.split('**Answer:**')[0].replaceAll('**Question:**', '').trim();
          backText = cleanContent.split('**Answer:**')[1].trim();
        } else if (cleanContent.contains('**Back:**')) {
          frontText = cleanContent.split('**Back:**')[0].replaceAll('**Front:**', '').trim();
          backText = cleanContent.split('**Back:**')[1].trim();
        } else {
          frontText = cleanContent;
          backText = "No back provided.";
        }
      } catch (e) {
        frontText = item.content;
        backText = "Could not parse answer.";
      }

      topPages.add(_buildCardFace(
        context: context,
        title: "Question",
        content: frontText,
        isDark: isDark,
      ));

      bottomPages.add(_buildCardFace(
        context: context,
        title: "Answer",
        content: backText,
        isDark: isDark,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Center(
        child: FlashCard(
          cardHeight: MediaQuery.of(context).size.height * 0.8, // Massive card!
          topPages: topPages,
          bottomPages: bottomPages,
          headerColor: isDark ? const Color(0xFF232338) : Colors.white,
          bottomColor: isDark ? const Color(0xFF2A2A40) : const Color(0xFFF0F0F5),
          topPageColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          bottomPageColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadiusAll: 24,
        ),
      ),
    );
  }

  // A helper function to draw a clean, elegant card face
  Widget _buildCardFace({
    required BuildContext context,
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.blueAccent : Colors.blueGrey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
