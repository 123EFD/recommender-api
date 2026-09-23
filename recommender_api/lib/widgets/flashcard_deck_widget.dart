import 'package:flutter/material.dart';
import 'package:animated_flash_cards/animated_flash_cards.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
          final parts = cleanContent.split('**Answer:**');
          frontText = parts[0].replaceAll('**Question:**', '').trim();
          backText = parts.sublist(1).join('**Answer:**').trim();
        } else if (cleanContent.contains('**Back:**')) {
          final parts = cleanContent.split('**Back:**');
          frontText = parts[0].replaceAll('**Front:**', '').trim();
          backText = parts.sublist(1).join('**Back:**').trim();
        } else {
          frontText = cleanContent;
          backText = "No back provided.";
        }
      } catch (e) {
        frontText = item.content;
        backText = "Could not parse answer.";
      }

      final promptTitle = item.topic.isNotEmpty ? "PROMPT • ${item.topic}" : "QUERY PROMPT";
      final answerTitle = item.topic.isNotEmpty ? "EXPLANATION • ${item.topic}" : "SYNTHESIZED EXPLANATION";

      topPages.add(_buildCardFace(
        context: context,
        title: promptTitle,
        content: frontText,
        isQuestion: true,
        index: i + 1,
        total: items.length,
        isDark: isDark,
      ));

      bottomPages.add(_buildCardFace(
        context: context,
        title: answerTitle,
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
                // Ensure balanced card viewport:
                // Cap width on wide desktop monitors (720px) to prevent stretched, flat cards.
                // Expand height comfortably (up to 720px) to provide ample reading room without constant scrolling.
                final double maxIdealWidth = 720.0;
                final double cardWidth = (constraints.maxWidth > maxIdealWidth + 24)
                    ? maxIdealWidth
                    : (constraints.maxWidth - 16).clamp(280.0, maxIdealWidth);
                final double cardHeight = (constraints.maxHeight - 12).clamp(360.0, 720.0);

                return Center(
                  child: SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: FlashCard(
                      cardHeight: cardHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      topPages: topPages,
                      bottomPages: bottomPages,
                      headerColor: isDark ? DarkAcademiaPalette.spaceCadet : const Color(0xFF6F4D38),
                      bottomColor: isDark ? DarkAcademiaPalette.charcoalSlate : const Color(0xFF4B3B2A),
                      topPageColor: isDark ? const Color(0xFF23252A) : const Color(0xFFFAF7F0),
                      bottomPageColor: isDark ? const Color(0xFF23252A) : const Color(0xFFFAF7F0),
                      borderRadiusAll: 16,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Sanitizes markdown, unescapes backticks, and auto-balances code fences
  String _cleanMarkdownForFlashcard(String raw) {
    if (raw.isEmpty) return raw;
    String text = raw;

    // Convert literal escaped newlines and quotes if encoded
    if (text.contains(r'\n')) {
      text = text.replaceAll(r'\n', '\n');
    }
    if (text.contains(r'\"')) {
      text = text.replaceAll(r'\"', '"');
    }

    // Unescape backticks and markdown symbols that may have been backslash-escaped in JSON responses
    text = text.replaceAll(r'\`', '`');
    text = text.replaceAll(r'\\`', '`');

    // Balance unclosed triple code fences if response was interrupted
    final fenceCount = RegExp(r'```').allMatches(text).length;
    if (fenceCount % 2 != 0) {
      text = '$text\n```';
    }

    return text.trim();
  }

  // A helper function to draw an archival library catalog card face with rich Markdown
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

    final cleanedContent = _cleanMarkdownForFlashcard(content);
    final hasCodeOrComplex = cleanedContent.contains('```') ||
        cleanedContent.contains('\n- ') ||
        cleanedContent.contains('\n* ') ||
        cleanedContent.contains('\n1.') ||
        !isQuestion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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

          const SizedBox(height: 10),

          // Archival Content - Takes all available space with rich Markdown and code block support
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: MarkdownBody(
                data: cleanedContent,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: isDark ? const Color(0xFFF2EFE9) : DarkAcademiaPalette.oxfordBrown,
                  ),
                  h1: GoogleFonts.cinzel(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                  ),
                  h2: GoogleFonts.cinzel(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                  ),
                  h3: GoogleFonts.cinzel(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.vintageMaroon,
                  ),
                  strong: TextStyle(
                    fontFamily: 'serif',
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                  ),
                  em: const TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                  ),
                  code: GoogleFonts.shareTechMono(
                    fontSize: 13,
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.vintageMaroon,
                    backgroundColor: isDark ? const Color(0xFF1B1D22) : const Color(0xFFEDE8DC),
                  ),
                  codeblockPadding: const EdgeInsets.all(12),
                  codeblockDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141619) : const Color(0xFFEDE8DC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3)
                          : DarkAcademiaPalette.tan.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  blockquote: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: DarkAcademiaPalette.fadedGold,
                        width: 3,
                      ),
                    ),
                  ),
                  textAlign: hasCodeOrComplex ? WrapAlignment.start : WrapAlignment.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
