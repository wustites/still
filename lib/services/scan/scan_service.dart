import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/models/scanned_file.dart';
import '../thumbnails/thumbnail_service.dart';
import 'media_scanner.dart';

/// Owns scan lifecycle state and keeps the UI informed.
class ScanService extends ChangeNotifier {
  ScanService({
    required LibraryRepository repository,
    required ThumbnailService thumbnails,
  }) : _repository = repository,
       _thumbnails = thumbnails;

  final LibraryRepository _repository;
  final ThumbnailService _thumbnails;

  bool _scanning = false;
  bool _cancelRequested = false;
  String? _currentRoot;
  ScanResult? _lastResult;
  String? _error;
  bool _warmupStarted = false;

  bool get scanning => _scanning;
  String? get currentRoot => _currentRoot;
  ScanResult? get lastResult => _lastResult;
  String? get error => _error;

  /// Scans every configured folder.
  Future<void> scanAll() => _run(() => _repository.watchRoots().first);

  /// Scans one folder.
  Future<void> scanRoot(LibraryRoot root) => _run(() async => [root]);

  /// Warms thumbnails for already indexed videos (called once after launch).
  Future<void> warmUpExisting({int limit = 60}) async {
    if (_warmupStarted) return;
    _warmupStarted = true;
    final items = await _repository.itemsNeedingThumbnails(limit: limit);
    unawaited(_thumbnails.warmUp(items));
  }

  Future<void> _run(Future<List<LibraryRoot>> Function() loadRoots) async {
    if (_scanning) return;
    _scanning = true;
    _cancelRequested = false;
    _lastResult = null;
    _error = null;
    notifyListeners();

    try {
      final incomplete = <String>[];
      for (final root in await loadRoots()) {
        if (_cancelRequested) break;
        _currentRoot = root.name;
        notifyListeners();

        final result = await MediaScanner.scan(root.path);
        if (_cancelRequested) break;
        await _repository.applyScan(root.id, result);
        _lastResult = result;
        if (result.errors > 0) {
          incomplete.add('${root.name}（${result.errors} 处无法读取）');
          _error = incomplete.join('、');
        }
        notifyListeners();
      }
      if (!_cancelRequested && _lastResult != null) {
        unawaited(_warmUpAfterScan());
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _scanning = false;
      _currentRoot = null;
      notifyListeners();
    }
  }

  Future<void> _warmUpAfterScan() async {
    final items = await _repository.itemsNeedingThumbnails(limit: 120);
    await _thumbnails.warmUp(items);
  }

  Future<void> cancel() async {
    // Let the current isolate or database transaction finish before accepting
    // another scan. Discard results that have not been submitted for writing.
    if (_scanning) _cancelRequested = true;
  }
}
