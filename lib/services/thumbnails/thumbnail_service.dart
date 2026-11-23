import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../data/db/app_database.dart';
import '../../data/models/media_kind.dart';
import '../../data/repositories/library_repository.dart';

/// Generates poster frames for videos.
///
/// media_kit can decode video, but probing every file through libmpv is far too
/// heavy for a grid. ffmpeg is used when present on `PATH`; without it the UI
/// falls back to a styled placeholder. Nothing here blocks the UI isolate:
/// [Process.run] is asynchronous and decoding happens in ffmpeg's own process.
class ThumbnailService {
  ThumbnailService(this._repository);

  final LibraryRepository _repository;

  Future<bool>? _ffmpegCheck;
  bool _warming = false;

  Future<bool> get hasFfmpeg => _ffmpegCheck ??= _checkFfmpeg();

  Future<void> warmUp(Iterable<MediaItem> items, {int concurrency = 2}) async {
    if (_warming) return;
    final queue = [
      for (final item in items)
        if (item.kind == MediaKind.video) item,
    ];
    if (queue.isEmpty || !await hasFfmpeg) return;

    _warming = true;
    try {
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final item = queue.removeAt(0);
          await generate(item);
        }
      }

      await Future.wait([
        for (var i = 0; i < concurrency.clamp(1, 4); i++) worker(),
      ]);
    } finally {
      _warming = false;
    }
  }

  /// Returns the thumbnail path, generating it when needed.
  Future<String?> generate(MediaItem item) async {
    if (item.kind != MediaKind.video) return null;

    final existing = item.thumbnailPath;
    if (existing != null) {
      if (await File(existing).exists()) return existing;
    }
    if (!await hasFfmpeg) return null;

    final directory = await AppPaths.thumbnailDirectory();
    final key = fnv1aHex(
      '${item.path}|${item.sizeBytes}|${item.modifiedAt.millisecondsSinceEpoch}',
    );
    final target = File(p.join(directory.path, '$key.jpg'));

    try {
      if (!await target.exists()) {
        var ok = await _extractFrame(item.path, target.path, seconds: 5);
        if (!ok) {
          ok = await _extractFrame(item.path, target.path, seconds: 0);
        }
        if (!ok) return null;
      }
      await _repository.setThumbnail(item.id, target.path);
      return target.path;
    } on ProcessException {
      return null;
    } on FileSystemException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<bool> _checkFfmpeg() async {
    try {
      final result = await Process.run(
        'ffmpeg',
        ['-version'],
        runInShell: true,
      ).timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _extractFrame(
    String input,
    String output, {
    required int seconds,
  }) async {
    final result = await Process.run(
      'ffmpeg',
      [
        '-nostdin',
        '-loglevel',
        'error',
        '-ss',
        '$seconds',
        '-i',
        input,
        '-frames:v',
        '1',
        '-vf',
        'scale=480:-2',
        '-q:v',
        '4',
        '-y',
        output,
      ],
      runInShell: true,
    ).timeout(const Duration(seconds: 30));
    return result.exitCode == 0 && await File(output).exists();
  }
}
