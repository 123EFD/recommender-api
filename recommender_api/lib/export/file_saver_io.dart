import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Desktop/Mobile implementation: Writes the bytes directly to a file
/// in the user's Downloads or Documents directory.
Future<String> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  // Try Downloads first (available on desktop), fall back to Documents
  final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}${Platform.pathSeparator}$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  return filePath;
}
