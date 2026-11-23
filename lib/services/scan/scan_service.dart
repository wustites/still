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
  String? _currentRoot;
  ScanResult? _lastResult;
  String? _error;
  bool _warmupStarted = false;

  bool get scanning => _scanning;
  String? get currentRoot => _currentRoot;
  ScanResult? get lastResult => _lastResult;
  String? get error => _error;

  /// Scans every configured folder.
  Future<void> scanAll() async {
    if (_scanning) return;
    final roots = await _repository.watchRoots().first;
    await _run(roots);
  }

  /// Scans one folder.
  Future<void> scanRoot(LibraryRoot root) async {
    if (_scanning) return;
    await _run([root]);
  }

  /// Warms thumbnails for already indexed videos (called once after launch).
  Future<void> warmUpExisting({int limit = 60}) async {
    if (_warmupStarted) return;
    _warmupStarted = true;
    final items = await _repository.itemsNeedingThumbnails(limit: limit);
    unawaited(_thumbnails.warmUp(items));
  }

  Future<void> _run(List<LibraryRoot> roots) async {
    if (roots.isEmpty) return;
    _scanning = true;
    _error = null;
    notifyListeners();

    try {
      for (final root in roots) {
        if (!_scanning) break;
        _currentRoot = root.name;
        notifyListeners();

        final result = await MediaScanner.scan(root.path);
        await _repository.applyScan(root.id, result.files);
        _lastResult = result;
        notifyListeners();
      }
      unawaited(_warmUpAfterScan());
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
    // The scan runs in an isolate; the next await point observes this flag.
    _scanning = false;
    _currentRoot = null;
    notifyListeners();
  }
}
