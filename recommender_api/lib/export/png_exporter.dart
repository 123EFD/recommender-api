import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'file_saver.dart' as file_saver;

/// Captures a widget subtree as a high-resolution PNG image
/// and saves it using the platform-appropriate method (web download or desktop file write).
///
/// [repaintKey] — The GlobalKey attached to the RepaintBoundary wrapping the mind map canvas.
/// [title] — Used to generate the output filename.
/// [context] — Needed to show the success/error SnackBar.
Future<void> exportAsPng({
  required GlobalKey repaintKey,
  required String title,
  required BuildContext context,
}) async {
  try {
    // Step 1: Grab the RenderRepaintBoundary from the widget tree using the GlobalKey.
    // This is the isolated render layer we wrapped around the mind map canvas.
    final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    // Step 2: Rasterize the boundary into pixels.
    // pixelRatio: 3.0 means 3x the screen resolution — produces a crisp, high-res export.
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);

    // Step 3: Encode the raster image into PNG byte format.
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode image to PNG bytes.');
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // Step 4: Sanitize the title for use as a filename (remove special characters).
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final fileName = '${safeTitle}_mindmap.png';

    // Step 5: Delegate to the platform-specific file saver.
    // On web: triggers a browser download dialog.
    // On desktop: writes to the Downloads folder and returns the file path.
    final result = await file_saver.saveFile(
      bytes: pngBytes,
      fileName: fileName,
      mimeType: 'image/png',
    );

    // Step 6: Show success feedback.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E293B),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.contains('/') || result.contains('\\')
                      ? 'Saved to: $result'
                      : 'Mind map PNG downloaded!',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red.shade800,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Export failed: $e', style: const TextStyle(color: Colors.white))),
            ],
          ),
        ),
      );
    }
  }
}
