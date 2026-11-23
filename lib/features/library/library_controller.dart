import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/models/media_filter.dart';
import '../../data/models/media_kind.dart';

enum LibraryScope { all, videos, images, recent, favorites, folder }

class LibrarySelection {
  const LibrarySelection.scope(this.scope) : root = null;
  const LibrarySelection.folder(this.root) : scope = LibraryScope.folder;

  final LibraryScope scope;
  final LibraryRoot? root;

  String get title => switch (scope) {
    LibraryScope.all => '全部媒体',
    LibraryScope.videos => '视频',
    LibraryScope.images => '图片',
    LibraryScope.recent => '最近播放',
    LibraryScope.favorites => '收藏',
    LibraryScope.folder => root?.name ?? '文件夹',
  };

  String? get path => root?.path;

  @override
  bool operator ==(Object other) {
    return other is LibrarySelection &&
        other.scope == scope &&
        other.root?.id == root?.id;
  }

  @override
  int get hashCode => Object.hash(scope, root?.id);
}

class LibraryController extends ChangeNotifier {
  LibrarySelection _selection = const LibrarySelection.scope(
    LibraryScope.all,
  );
  MediaSort _sort = MediaSort.name;
  String _query = '';
  String _searchInput = '';
  Timer? _searchDebounce;
  bool _disposed = false;

  LibrarySelection get selection => _selection;
  MediaSort get sort => _sort;
  String get query => _query;
  String get searchInput => _searchInput;

  MediaFilter get filter => MediaFilter(
    rootId: _selection.root?.id,
    kind: switch (_selection.scope) {
      LibraryScope.videos => MediaKind.video,
      LibraryScope.images => MediaKind.image,
      _ => null,
    },
    favoritesOnly: _selection.scope == LibraryScope.favorites,
    recentOnly: _selection.scope == LibraryScope.recent,
    query: _query,
    sort: _sort,
    limit: _selection.scope == LibraryScope.recent ? 200 : null,
  );

  void selectScope(LibraryScope scope) {
    if (scope == LibraryScope.folder) return;
    if (scope == LibraryScope.recent) {
      _sort = MediaSort.lastPlayed;
    }
    _select(LibrarySelection.scope(scope));
  }

  void selectRoot(LibraryRoot root) {
    _select(LibrarySelection.folder(root));
  }

  void _select(LibrarySelection selection) {
    if (selection == _selection) return;
    _selection = selection;
    _notify();
  }

  void setSort(MediaSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    _notify();
  }

  /// Debounced so typing does not fire a database query per keystroke.
  void setSearchInput(String value) {
    _searchInput = value;
    _notify();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (_disposed || value == _query) return;
      _query = value;
      _notify();
    });
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _searchInput = '';
    _query = '';
    _notify();
  }

  /// Keeps the selection valid after a library folder is removed.
  void reconcileRoots(List<LibraryRoot> roots) {
    final selected = _selection.root;
    if (selected == null) return;
    if (roots.any((root) => root.id == selected.id)) return;
    _selection = const LibrarySelection.scope(LibraryScope.all);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}
