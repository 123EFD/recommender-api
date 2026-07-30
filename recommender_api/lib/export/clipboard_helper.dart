import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies the Mermaid diagram syntax string to the system clipboard
/// and shows a styled SnackBar confirming the action.
///
/// [mermaidCode] — The raw Mermaid string from the backend response (e.g., "graph TD\n  A --> B").
/// [context] — Needed to display the SnackBar.
void copyMermaidCode({
  required String? mermaidCode,
  required BuildContext context,
}) {
  // Guard: If the backend didn't return any mermaid code, show an error.
  if (mermaidCode == null || mermaidCode.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.orange.shade800,
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('No Mermaid code available for this map.', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
    return;
  }

  // Copy the mermaid code string to the OS clipboard.
  Clipboard.setData(ClipboardData(text: mermaidCode));

  // Show success confirmation.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF1E293B),
      content: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
          SizedBox(width: 10),
          Text('Mermaid code copied to clipboard!', style: TextStyle(color: Colors.white)),
        ],
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
