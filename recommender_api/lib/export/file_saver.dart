/// Conditional import dispatcher.
/// At compile time, Dart selects the correct implementation:
///   - If `dart:html` is available (web build) → uses file_saver_web.dart
///   - If `dart:io` is available (desktop/mobile build) → uses file_saver_io.dart
///   - Otherwise → uses file_saver_stub.dart (throws UnsupportedError)
export 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';
