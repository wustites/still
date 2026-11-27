import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../data/models/media_kind.dart';
import '../../data/models/scanned_file.dart';

/// Depth-first directory walk over `dart:io`.
///
/// The walk itself runs on a background isolate so a slow network share or a
/// million-file folder never blocks the UI isolate. Symlinks are not followed,
/// so a self-referencing link cannot trap the walk.
abstract final class MediaScanner {
  static const Set<String> _ignoredDirectoryNames = {
    r'$RECYCLE.BIN',
    'System Volume Information',
    'node_modules',
  };

  static Future<ScanResult> scan(String rootPath) {
    return Isolate.run(() => _scanSync(rootPath));
  }

  /// Synchronous core of [scan]. Public for tests that want to avoid isolate
  /// startup; production code should call [scan].
  static ScanResult scanSync(String rootPath) => _scanSync(rootPath);
}

ScanResult _scanSync(String rootPath) {
  final stopwatch = Stopwatch()..start();
  final root = Directory(rootPath);
  final files = <ScannedFile>[];
  var errors = 0;

  if (!root.existsSync()) {
    return ScanResult(
      files: const [],
      errors: 1,
      elapsed: stopwatch.elapsed,
    );
  }

  final pending = <Directory>[root];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(followLinks: false);
    } on FileSystemException {
      errors++;
      continue;
    }

    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        if (MediaScanner._ignoredDirectoryNames.contains(name)) continue;
        pending.add(entity);
        continue;
      }
      if (entity is! File) continue;

      final kind = MediaFormats.kindOf(entity.path);
      if (kind == null) continue;

      try {
        final stat = entity.statSync();
        if (stat.type == FileSystemEntityType.notFound) {
          errors++;
          continue;
        }
        files.add(
          ScannedFile(
            path: entity.path,
            name: name,
            extension: p.extension(entity.path).toLowerCase(),
            kind: kind,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      } on FileSystemException {
        errors++;
      }
    }
  }

  return ScanResult(
    files: files,
    errors: errors,
    elapsed: stopwatch.elapsed,
  );
}
