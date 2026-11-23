import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/media_kind.dart';
import '../../../services/media/exif_service.dart';
import '../../../ui/theme.dart';

class ExifPanel extends StatefulWidget {
  const ExifPanel({super.key, required this.item, required this.onClose});

  final MediaItem item;
  final VoidCallback onClose;

  @override
  State<ExifPanel> createState() => _ExifPanelState();
}

class _ExifPanelState extends State<ExifPanel> {
  late Future<Map<String, String>> _exif;

  @override
  void initState() {
    super.initState();
    _exif = ExifService.read(widget.item.path);
  }

  @override
  void didUpdateWidget(covariant ExifPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _exif = ExifService.read(widget.item.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xF215171A),
        border: Border(left: BorderSide(color: StillColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '文件信息',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: StillColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                _InfoRow(label: '文件名', value: item.name),
                _InfoRow(label: '类型', value: item.kind.label),
                _InfoRow(label: '大小', value: formatBytes(item.sizeBytes)),
                _InfoRow(
                  label: '修改时间',
                  value: formatDateTime(item.modifiedAt),
                ),
                _InfoRow(label: '路径', value: item.path, selectable: true),
                const SizedBox(height: 16),
                const Text(
                  'EXIF',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: StillColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                FutureBuilder<Map<String, String>>(
                  future: _exif,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        ),
                      );
                    }
                    final data = snapshot.data ?? const <String, String>{};
                    if (data.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '没有可读取的 EXIF 信息',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: StillColors.muted,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final entry in data.entries)
                          _InfoRow(label: entry.key, value: entry.value),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11.5,
      height: 1.4,
      color: selectable ? StillColors.text : StillColors.muted,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: StillColors.muted),
          ),
          const SizedBox(height: 2),
          selectable
              ? SelectableText(value, style: style)
              : Text(value, style: style),
        ],
      ),
    );
  }
}
