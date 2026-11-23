import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/media_kind.dart';
import '../../../ui/theme.dart';

class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final MediaItem item;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final durationMs = item.durationMs ?? 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: StillColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering ? StillColors.accent : StillColors.border,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _MediaPreview(item: item),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _hovering ? 1 : 0,
                        duration: const Duration(milliseconds: 140),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x99000000)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Color(0xCC000000),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.kind.isVideo
                                  ? Icons.play_arrow_rounded
                                  : Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (durationMs > 0)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _Badge(
                          text: formatDuration(
                            Duration(milliseconds: durationMs),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: AnimatedOpacity(
                        opacity: _hovering || item.favorite ? 1 : 0,
                        duration: const Duration(milliseconds: 140),
                        child: IconButton(
                          tooltip: item.favorite ? '取消收藏' : '收藏',
                          onPressed: widget.onToggleFavorite,
                          icon: Icon(
                            item.favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: item.favorite
                                ? StillColors.accent
                                : Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x99000000),
                            minimumSize: const Size(30, 30),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    if (durationMs > 0 && item.positionMs > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: (item.positionMs / durationMs)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                          minHeight: 2.5,
                          backgroundColor: Colors.transparent,
                          color: StillColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: StillColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _meta(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: StillColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _meta(MediaItem item) {
    final parts = <String>[item.kind.label];
    final duration = item.durationMs;
    if (duration != null && duration > 0) {
      parts.add(formatDuration(Duration(milliseconds: duration)));
    }
    parts.add(formatBytes(item.sizeBytes));
    return parts.join(' · ');
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final target = item.thumbnailPath ?? item.path;
    if (item.kind.isVideo && item.thumbnailPath == null) {
      return _VideoPlaceholder(name: item.name);
    }

    return Image.file(
      File(target),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      cacheWidth: 600,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          _VideoPlaceholder(name: item.name),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = (name.hashCode.abs() % 40) + 210.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.18, 0.20).toColor(),
            const Color(0xFF101215),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          size: 30,
          color: Color(0x66FFFFFF),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}
