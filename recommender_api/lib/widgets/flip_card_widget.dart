import 'package:flutter/material.dart';
import 'package:animated_flash_cards/animated_flash_cards.dart';
import '../models/resource_item.dart';

class FlipCardWidget extends StatelessWidget {
  final ResourceItem item;

  const FlipCardWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

    return FlashCard(
      topPages: [
        _buildCardFace(
          context,
          title: "Question",
          content: frontText,
          color: Colors.blueAccent.withOpacity(0.1),
        ),
      ],
      bottomPages: [
        _buildCardFace(
          context,
          title: "Answer",
          content: backText,
          color: Colors.greenAccent.withOpacity(0.1),
        ),
      ],
    );
  }

  // A helper function to draw a beautiful Glassmorphism-style card face
  Widget _buildCardFace(BuildContext context, {required String title, required String content, required Color color}) {
    return Container(
      // Ensure the container expands fully within its grid cell boundaries
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}