import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../../data/models/media_filter.dart';
import '../../data/models/media_kind.dart';
import '../../data/repositories/library_repository.dart';
import '../../services/scan/scan_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/empty_state.dart';
import '../player/video_page.dart';
import '../settings/settings_page.dart';
import '../viewer/image_viewer_page.dart';
import 'library_controller.dart';
import 'widgets/library_sidebar.dart';
import 'widgets/library_toolbar.dart';
import 'widgets/media_tile.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final LibraryRepository _repository;
  late final ScanService _scan;
  late final LibraryController _controller;

  StreamSubscription<List<LibraryRoot>>? _rootsSubscription;
  StreamSubscription<List<MediaItem>>? _itemsSubscription;
  MediaFilter? _subscribedFilter;

  List<LibraryRoot> _roots = const [];
  List<MediaItem> _items = const [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _repository = context.read<LibraryRepository>();
    _scan = context.read<ScanService>();
    _controller = LibraryController()..addListener(_onFilterChanged);

    _rootsSubscription = _repository.watchRoots().listen((roots) {
      if (!mounted) return;
      _controller.reconcileRoots(roots);
      setState(() => _roots = roots);
    });
    _resubscribe();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scan.warmUpExisting());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onFilterChanged);
    _controller.dispose();
    _rootsSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }

  void _onFilterChanged() {
    final filter = _controller.filter;
    if (filter != _subscribedFilter) {
      _resubscribe();
    }
    if (mounted) setState(() {});
  }

  void _resubscribe() {
    final filter = _controller.filter;
    _subscribedFilter = filter;
    _itemsSubscription?.cancel();
    _itemsSubscription = _repository.watchMedia(filter).listen((items) {
      if (!mounted) return;
      setState(() => _items = items);
    });
  }

  Future<void> _addFolder() async {
    final path = await getDirectoryPath(confirmButtonText: '添加文件夹');
    if (path == null || !mounted) return;

    try {
      final root = await _repository.addRoot(path);
      if (!mounted) return;
      _controller.selectRoot(root);
      await _scan.scanRoot(root);
      if (!mounted) return;
      _showMessage('已添加 ${root.name}');
    } catch (error) {
      if (!mounted) return;
      _showMessage('添加失败：$error', error: true);
    }
  }

  Future<void> _removeRoot(LibraryRoot root) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除文件夹'),
        content: Text('确定要从媒体库移除「${root.name}」吗？\n不会删除磁盘上的任何文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: StillColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.removeRoot(root.id);
    if (!mounted) return;
    _showMessage('已移除 ${root.name}');
  }

  Future<void> _refresh() async {
    final root = _controller.selection.root;
    if (root != null) {
      await _scan.scanRoot(root);
    } else {
      await _scan.scanAll();
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          width: 360,
          backgroundColor: error ? StillColors.danger : StillColors.surfaceHigh,
        ),
      );
  }

  void _openItem(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (item.kind == MediaKind.video) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPage(items: _items, initialIndex: index),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerPage(items: _items, initialIndex: index),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = _controller.selection;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibrarySidebar(
            roots: _roots,
            selection: selection,
            scanning: _scan.scanning,
            onSelectScope: _controller.selectScope,
            onSelectRoot: _controller.selectRoot,
            onAddFolder: _addFolder,
            onRemoveRoot: _removeRoot,
            onRescanRoot: (root) => unawaited(_scan.scanRoot(root)),
            onScanAll: () => unawaited(_scan.scanAll()),
            onOpenSettings: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
          Expanded(
            child: Column(
              children: [
                LibraryToolbar(
                  title: selection.title,
                  count: _items.length,
                  search: _controller.searchInput,
                  sort: _controller.sort,
                  onSearchChanged: _controller.setSearchInput,
                  onSortChanged: _controller.setSort,
                  onRefresh: () => unawaited(_refresh()),
                ),
                AnimatedBuilder(
                  animation: _scan,
                  builder: (context, _) {
                    if (!_scan.scanning) {
                      if (_scan.error == null) return const SizedBox.shrink();
                      return _ScanBanner(
                        text: '扫描失败：${_scan.error}',
                        error: true,
                      );
                    }
                    final root = _scan.currentRoot;
                    return _ScanBanner(
                      text: root == null ? '正在扫描媒体库…' : '正在扫描 $root…',
                    );
                  },
                ),
                Expanded(child: _buildContent(selection)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LibrarySelection selection) {
    if (_roots.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_rounded,
        title: '媒体库是空的',
        message: '添加一个包含视频或图片的文件夹，Still 会在后台建立索引。',
        action: FilledButton.icon(
          onPressed: _addFolder,
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('添加文件夹'),
          style: FilledButton.styleFrom(
            backgroundColor: StillColors.accent,
            foregroundColor: const Color(0xFF241505),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      if (_controller.query.isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          title: '没有匹配的项目',
          message: '试试其他关键词，或清空搜索。',
          action: TextButton(
            onPressed: _controller.clearSearch,
            child: const Text('清空搜索'),
          ),
        );
      }
      return EmptyState(
        icon: selection.scope == LibraryScope.images
            ? Icons.image_not_supported_outlined
            : Icons.movie_filter_outlined,
        title: '这里还没有内容',
        message: selection.scope == LibraryScope.recent
            ? '播放过的文件会出现在这里。'
            : '扫描文件夹，或切换到其他分类看看。',
        action: OutlinedButton.icon(
          onPressed: () => unawaited(_refresh()),
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('重新扫描'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.28,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return MediaTile(
          key: ValueKey(item.id),
          item: item,
          onOpen: () => _openItem(index),
          onToggleFavorite: () {
            unawaited(_repository.setFavorite(item.id, !item.favorite));
          },
        );
      },
    );
  }
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      color: error ? const Color(0x332B1515) : const Color(0x1AFFB35C),
      child: Row(
        children: [
          if (!error)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: StillColors.accent,
              ),
            )
          else
            const Icon(Icons.error_outline_rounded, size: 15, color: StillColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: error ? StillColors.danger : StillColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
