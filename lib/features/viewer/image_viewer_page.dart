import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/db/app_database.dart';
import '../../ui/theme.dart';
import 'widgets/exif_panel.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TransformationController _transform = TransformationController();

  late int _index;
  int _quarterTurns = 0;
  bool _cover = false;
  bool _chromeVisible = true;
  bool _infoVisible = false;

  MediaItem get _item => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbors());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) _precacheNeighbors();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _precacheNeighbors() {
    for (final offset in const [-1, 1]) {
      final index = _index + offset;
      if (index < 0 || index >= widget.items.length) continue;
      unawaited(
        precacheImage(
          FileImage(File(widget.items[index].path)),
          context,
        ).catchError((_) {}),
      );
    }
  }

  void _goTo(int index) {
    final next = index.clamp(0, widget.items.length - 1).toInt();
    if (next == _index) return;
    setState(() {
      _index = next;
      _quarterTurns = 0;
      _cover = false;
    });
    _resetTransform();
    _precacheNeighbors();
  }

  void _resetTransform() {
    _transform.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);
    final scenePoint = _transform.toScene(center);
    final matrix = _transform.value.clone()
      ..scaleByDouble(factor, factor, 1, 1);
    final moved = MatrixUtils.transformPoint(matrix, scenePoint);
    matrix.translateByDouble(
      center.dx - moved.dx,
      center.dy - moved.dy,
      0,
      1,
    );
    _transform.value = matrix;
  }

  void _rotate() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  void _toggleFit() {
    setState(() => _cover = !_cover);
    _resetTransform();
  }

  void _toggleChrome() {
    setState(() {
      _chromeVisible = !_chromeVisible;
      if (!_chromeVisible) _infoVisible = false;
    });
  }

  void _toggleInfo() {
    setState(() {
      _infoVisible = !_infoVisible;
      _chromeVisible = true;
    });
  }

  void _handleEscape() {
    if (_infoVisible) {
      setState(() => _infoVisible = false);
      return;
    }
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
        _goTo(_index + 1),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _goTo(_index - 1),
    const SingleActivator(LogicalKeyboardKey.space): () => _goTo(_index + 1),
    const SingleActivator(LogicalKeyboardKey.equal): () => _zoomBy(1.25),
    const SingleActivator(LogicalKeyboardKey.numpadAdd): () => _zoomBy(1.25),
    const SingleActivator(LogicalKeyboardKey.minus): () => _zoomBy(0.8),
    const SingleActivator(LogicalKeyboardKey.numpadSubtract): () =>
        _zoomBy(0.8),
    const SingleActivator(LogicalKeyboardKey.digit0): _resetTransform,
    const SingleActivator(LogicalKeyboardKey.keyR): _rotate,
    const SingleActivator(LogicalKeyboardKey.keyF): _toggleChrome,
    const SingleActivator(LogicalKeyboardKey.keyI): _toggleInfo,
    const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        child: CallbackShortcuts(
          bindings: _shortcuts,
          child: MouseRegion(
            onHover: (_) {
              if (!_chromeVisible) setState(() => _chromeVisible = true);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(),
                _buildTopBar(),
                if (_infoVisible)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      child: ExifPanel(
                        item: _item,
                        onClose: () => setState(() => _infoVisible = false),
                      ),
                    ),
                  ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth = MediaQuery.sizeOf(context).width;
    final cacheWidth = (logicalWidth * dpr * 1.5)
        .clamp(1024.0, 4096.0)
        .round();

    return InteractiveViewer(
      transformationController: _transform,
      minScale: 0.5,
      maxScale: 8,
      boundaryMargin: const EdgeInsets.all(160),
      child: SizedBox.expand(
        child: RotatedBox(
          quarterTurns: _quarterTurns,
          child: Image.file(
            File(_item.path),
            key: ValueKey(_item.id),
            fit: _cover ? BoxFit.cover : BoxFit.contain,
            filterQuality: FilterQuality.medium,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 36,
                      color: StillColors.muted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '无法读取这张图片',
                      style: TextStyle(
                        fontSize: 13,
                        color: StillColors.muted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 170),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB3000000), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回 (Esc)',
                  onPressed: () => Navigator.of(context).maybePop(),
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_index + 1} / ${widget.items.length}'
                        '  ·  ${_quarterTurns * 90}°',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                _ToolbarIcon(
                  icon: _cover
                      ? Icons.fit_screen_rounded
                      : Icons.crop_free_rounded,
                  tooltip: _cover ? '适应窗口' : '填满窗口',
                  onPressed: _toggleFit,
                ),
                _ToolbarIcon(
                  icon: Icons.rotate_90_degrees_cw_rounded,
                  tooltip: '旋转 (R)',
                  onPressed: _rotate,
                ),
                _ToolbarIcon(
                  icon: Icons.zoom_out_rounded,
                  tooltip: '缩小 (-)',
                  onPressed: () => _zoomBy(0.8),
                ),
                _ToolbarIcon(
                  icon: Icons.zoom_in_rounded,
                  tooltip: '放大 (+)',
                  onPressed: () => _zoomBy(1.25),
                ),
                _ToolbarIcon(
                  icon: Icons.restart_alt_rounded,
                  tooltip: '重置 (0)',
                  onPressed: _resetTransform,
                ),
                _ToolbarIcon(
                  icon: Icons.info_outline_rounded,
                  tooltip: '文件信息 (I)',
                  selected: _infoVisible,
                  onPressed: _toggleInfo,
                ),
                _ToolbarIcon(
                  icon: _chromeVisible
                      ? Icons.fullscreen_rounded
                      : Icons.fullscreen_exit_rounded,
                  tooltip: '沉浸模式 (F)',
                  onPressed: _toggleChrome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 170),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x99000000), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                if (_index > 0)
                  TextButton.icon(
                    onPressed: () => _goTo(_index - 1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('上一张'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                const Spacer(),
                Text(
                  '滚轮缩放 · 拖动平移 · ←/→ 切换',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const Spacer(),
                if (_index < widget.items.length - 1)
                  TextButton.icon(
                    onPressed: () => _goTo(_index + 1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('下一张'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
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

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 19,
      color: selected ? StillColors.accent : Colors.white,
      icon: Icon(icon),
    );
  }
}
