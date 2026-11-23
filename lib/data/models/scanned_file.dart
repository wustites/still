import 'package:path/path.dart' as p;

import 'media_kind.dart';

/// A media file found by the scanner. Deliberately contains only primitives so
/// it can be sent across an isolate boundary.
class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.kind,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String path;
  final String name;
  final String extension;
  final MediaKind kind;
  final int sizeBytes;
  final DateTime modifiedAt;

  factory ScannedFile.fromPath(
    String path, {
    required int sizeBytes,
    required DateTime modifiedAt,
  }) {
    final kind = MediaFormats.kindOf(path);
    if (kind == null) {
      throw ArgumentError.value(path, 'path', 'Not a supported media file');
    }
    return ScannedFile(
      path: path,
      name: p.basename(path),
      extension: p.extension(path).toLowerCase(),
      kind: kind,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
    );
  }
}

/// Outcome of a directory scan.
class ScanResult {
  const ScanResult({
    required this.files,
    required this.errors,
    required this.elapsed,
  });

  final List<ScannedFile> files;

  /// Number of directories or files that could not be read (permissions,
  /// vanished files, ...). A non-zero value is not fatal.
  final int errors;
  final Duration elapsed;

  int get found => files.length;
}
