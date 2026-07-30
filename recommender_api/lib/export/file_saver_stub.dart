import 'dart:typed_data';

/// Abstract interface for saving files.
/// The correct platform implementation is selected at compile time
/// via conditional imports in `file_saver.dart`.
Future<String> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Cannot save files on this platform.');
}
