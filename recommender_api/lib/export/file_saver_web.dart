// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web implementation: Creates an invisible <a> download link,
/// sets its href to a Blob URL of the image bytes,
/// and programmatically clicks it to trigger the browser's download dialog.
Future<String> saveFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType, // e.g., 'image/png'
}) async {
  // 1. Convert Dart Uint8List to JS Uint8Array
  final jsArray = bytes.toJS;

  // 2. Create the Blob using the JS interop API so that browser's DOM understands it
  final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: mimeType));

  // 3. generate temp., fake URL, blob (Binary Large Object) is a standard browser feature
  final url = web.URL.createObjectURL(blob);

  // 4. Create the anchor element and trigger download
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url //HTML5 that dorce the browser to download whatever is in the href
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor); //put invisible link on webpage
  anchor.click(); //simulate mouse click on it

  // 5. Clean up: remove the anchor and revoke the blob URL to free memory
  anchor.remove();
  web.URL.revokeObjectURL(url);

  return 'Downloaded via browser';
}
