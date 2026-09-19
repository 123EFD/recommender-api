import 'package:flutter/material.dart';
import 'package:animated_flash_cards/animated_flash_cards.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/resource_item.dart';
import '../theme/app_theme.dart';

class FlashcardDeckWidget extends StatelessWidget {
  final List<ResourceItem> items;

  const FlashcardDeckWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          "No archival flashcards available.",
          style: GoogleFonts.cinzel(fontSize: 16, color: DarkAcademiaPalette.slateGray),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Widget> topPages = [];
    List<Widget> bottomPages = [];

    for (int i = 0; i < items.length; i++) {
      var item = items[i];
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
        title: "QUERY PROMPT",
        content: frontText,
        isQuestion: true,
        index: i + 1,
        total: items.length,
        isDark: isDark,
      ));

      bottomPages.add(_buildCardFace(
        context: context,
        title: "SYNTHESIZED EXPLANATION",
        content: backText,
        isQuestion: false,
        index: i + 1,
        total: items.length,
        isDark: isDark,
      ));
    }

    final estMinutes = (items.length * 1.5).ceil();

    return Column(
      children: [
        // Archival Bookmark Header
        Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 4.0, left: 12.0, right: 12.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.tan.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4)
                      : DarkAcademiaPalette.tan,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark, size: 14, color: DarkAcademiaPalette.fadedGold),
                  const SizedBox(width: 8),
                  Text(
                    "FOLIO COLLECTION • ${items.length} CARDS",
                    style: GoogleFonts.cinzel(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white : DarkAcademiaPalette.caputMortuum,
                    ),
                  ),
                  Container(
                    height: 12,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4) : DarkAcademiaPalette.tan,
                  ),
                  Text(
                    "~$estMinutes MIN READ",
                    style: GoogleFonts.shareTechMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Outer Dark Rim Tap / Flip Guidance
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? DarkAcademiaPalette.charcoalSlate.withValues(alpha: 0.8) : DarkAcademiaPalette.tan.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "TAP OUTER RIM OR SWIPE VERTICALLY TO FLIP",
                    style: GoogleFonts.shareTechMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.9,
                      color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Flashcard Deck
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight = (constraints.maxHeight - 12).clamp(240.0, 560.0);
                return Center(
                  child: FlashCard(
                    cardHeight: cardHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    topPages: topPages,
                    bottomPages: bottomPages,
                    headerColor: isDark ? DarkAcademiaPalette.spaceCadet : const Color(0xFF6F4D38),
                    bottomColor: isDark ? DarkAcademiaPalette.charcoalSlate : const Color(0xFF4B3B2A),
                    topPageColor: isDark ? const Color(0xFF23252A) : const Color(0xFFFAF7F0),
                    bottomPageColor: isDark ? const Color(0xFF23252A) : const Color(0xFFFAF7F0),
                    borderRadiusAll: 16,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // A helper function to draw an archival library catalog card face
  Widget _buildCardFace({
    required BuildContext context,
    required String title,
    required String content,
    required bool isQuestion,
    required int index,
    required int total,
    required bool isDark,
  }) {
    final badgeColor = isQuestion
        ? (isDark ? DarkAcademiaPalette.caputMortuum : DarkAcademiaPalette.vintageMaroon)
        : DarkAcademiaPalette.forestMoss;

    final isLong = content.length > 90;
    final fontSize = isLong ? 14.0 : 16.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25)
              : DarkAcademiaPalette.tan.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Catalog Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: DarkAcademiaPalette.fadedGold,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isQuestion ? Icons.help_outline : Icons.menu_book,
                        size: 12,
                        color: DarkAcademiaPalette.fadedGold,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.cinzel(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "CARD $index / $total",
                style: GoogleFonts.shareTechMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Archival Content - Takes all available space cleanly without footer cutoffs
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Text(
                    content,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
