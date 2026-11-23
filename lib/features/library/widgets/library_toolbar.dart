import 'package:flutter/material.dart';

import '../../../data/models/media_filter.dart';
import '../../../ui/theme.dart';

class LibraryToolbar extends StatefulWidget {
  const LibraryToolbar({
    super.key,
    required this.title,
    required this.count,
    required this.search,
    required this.sort,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onRefresh,
  });

  final String title;
  final int count;
  final String search;
  final MediaSort sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MediaSort> onSortChanged;
  final VoidCallback onRefresh;

  @override
  State<LibraryToolbar> createState() => _LibraryToolbarState();
}

class _LibraryToolbarState extends State<LibraryToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(covariant LibraryToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.search != _searchController.text) {
      _searchController.text = widget.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StillColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: StillColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.count} 个项目',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: StillColors.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 260,
            height: 34,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {});
                widget.onSearchChanged(value);
              },
              style: const TextStyle(fontSize: 12.5, color: StillColors.text),
              decoration: InputDecoration(
                hintText: '搜索名称…',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: StillColors.muted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: StillColors.muted,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        iconSize: 14,
                        tooltip: '清空',
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: StillColors.surfaceHigh,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: StillColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: StillColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: StillColors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<MediaSort>(
            tooltip: '排序',
            initialValue: widget.sort,
            onSelected: widget.onSortChanged,
            itemBuilder: (context) => [
              for (final sort in MediaSort.values)
                PopupMenuItem(
                  value: sort,
                  child: Row(
                    children: [
                      Icon(
                        sort == widget.sort
                            ? Icons.check_rounded
                            : Icons.sort_rounded,
                        size: 15,
                        color: sort == widget.sort
                            ? StillColors.accent
                            : StillColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Text(sort.label),
                    ],
                  ),
                ),
            ],
            child: _ToolbarButton(
              icon: Icons.swap_vert_rounded,
              label: widget.sort.label,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '重新扫描',
            onPressed: widget.onRefresh,
            iconSize: 18,
            color: StillColors.muted,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: StillColors.surfaceHigh,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: StillColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: StillColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: StillColors.text),
          ),
        ],
      ),
    );
  }
}
