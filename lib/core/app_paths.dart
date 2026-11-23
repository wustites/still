import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Locations Still owns on disk.
abstract final class AppPaths {
  /// Generated video poster frames.
  static Future<Directory> thumbnailDirectory() async {
    final support = await getApplicationSupportDirectory();
    return _ensure(p.join(support.path, 'thumbnails'));
  }

  /// Screenshots taken from the player.
  static Future<Directory> screenshotDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return _ensure(p.join(documents.path, 'Still', 'Screenshots'));
  }

  static Future<Directory> _ensure(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

/// Stable, dependency-free hash used for thumbnail file names.
///
/// FNV-1a 64-bit is deterministic across runs and platforms, unlike
/// [String.hashCode] which is only guaranteed within a single process.
String fnv1aHex(String input) {
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xffffffffffffffff;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
