import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../../ui/theme.dart';
import '../library_controller.dart';

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.roots,
    required this.selection,
    required this.scanning,
    required this.onSelectScope,
    required this.onSelectRoot,
    required this.onAddFolder,
    required this.onRemoveRoot,
    required this.onRescanRoot,
    required this.onScanAll,
    required this.onOpenSettings,
  });

  final List<LibraryRoot> roots;
  final LibrarySelection selection;
  final bool scanning;
  final ValueChanged<LibraryScope> onSelectScope;
  final ValueChanged<LibraryRoot> onSelectRoot;
  final VoidCallback onAddFolder;
  final ValueChanged<LibraryRoot> onRemoveRoot;
  final ValueChanged<LibraryRoot> onRescanRoot;
  final VoidCallback onScanAll;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 238,
      color: StillColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 6),
          _NavItem(
            icon: Icons.video_library_outlined,
            label: '全部媒体',
            selected: selection.scope == LibraryScope.all,
            onTap: () => onSelectScope(LibraryScope.all),
          ),
          _NavItem(
            icon: Icons.movie_outlined,
            label: '视频',
            selected: selection.scope == LibraryScope.videos,
            onTap: () => onSelectScope(LibraryScope.videos),
          ),
          _NavItem(
            icon: Icons.image_outlined,
            label: '图片',
            selected: selection.scope == LibraryScope.images,
            onTap: () => onSelectScope(LibraryScope.images),
          ),
          _NavItem(
            icon: Icons.history_rounded,
            label: '最近播放',
            selected: selection.scope == LibraryScope.recent,
            onTap: () => onSelectScope(LibraryScope.recent),
          ),
          _NavItem(
            icon: Icons.favorite_border_rounded,
            label: '收藏',
            selected: selection.scope == LibraryScope.favorites,
            onTap: () => onSelectScope(LibraryScope.favorites),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '文件夹',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: StillColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: roots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '还没有添加文件夹',
                      style: TextStyle(fontSize: 12, color: StillColors.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: roots.length,
                    itemBuilder: (context, index) {
                      final root = roots[index];
                      return _RootItem(
                        root: root,
                        selected:
                            selection.scope == LibraryScope.folder &&
                            selection.root?.id == root.id,
                        onTap: () => onSelectRoot(root),
                        onRescan: () => onRescanRoot(root),
                        onRemove: () => onRemoveRoot(root),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onAddFolder,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('添加文件夹'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StillColors.text,
                    side: const BorderSide(color: StillColors.border),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _FooterAction(
                  icon: scanning
                      ? Icons.sync_rounded
                      : Icons.manage_search_rounded,
                  label: scanning ? '正在扫描…' : '重新扫描全部',
                  onTap: scanning ? null : onScanAll,
                ),
                _FooterAction(
                  icon: Icons.settings_outlined,
                  label: '设置',
                  onTap: onOpenSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STILL',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: 5,
              color: StillColors.text,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '本地影音库',
            style: TextStyle(fontSize: 11, color: StillColors.muted),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? StillColors.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? StillColors.accent : StillColors.muted,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? StillColors.text : StillColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RootItem extends StatelessWidget {
  const _RootItem({
    required this.root,
    required this.selected,
    required this.onTap,
    required this.onRescan,
    required this.onRemove,
  });

  final LibraryRoot root;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRescan;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? StillColors.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 3, 2, 3),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: selected ? StillColors.accent : StillColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        root.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: selected
                              ? StillColors.text
                              : StillColors.muted,
                        ),
                      ),
                      Text(
                        root.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6C727A),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '文件夹操作',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: StillColors.muted,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'rescan':
                        onRescan();
                        break;
                      case 'remove':
                        onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rescan', child: Text('重新扫描')),
                    PopupMenuItem(value: 'remove', child: Text('从库中移除')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: StillColors.muted,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
