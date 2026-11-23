import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/library_repository.dart';
import '../../ui/theme.dart';
import '../settings/settings_controller.dart';
import 'player_controller.dart';
import 'widgets/video_controls.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late final PlayerController _controller;
  late final SettingsController _settings;
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();

  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _pointerOverControls = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsController>();
    _controller = PlayerController(
      repository: context.read<LibraryRepository>(),
      settings: _settings,
    );
    _settings.addListener(_onSettingsChanged);
    unawaited(_controller.openQueue(widget.items, widget.initialIndex));
    _scheduleHide();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || _pointerOverControls) return;
      if (_controller.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _setPointerOverControls(bool value) {
    _pointerOverControls = value;
    if (value) {
      _showControls();
    } else {
      _scheduleHide();
    }
  }

  Future<void> _toggleFullscreen() async {
    final state = _videoKey.currentState;
    if (state == null) return;
    try {
      final isFullscreen = state.isFullscreen();
      if (isFullscreen) {
        await state.exitFullscreen();
      } else {
        await state.enterFullscreen();
      }
      if (mounted) setState(() => _fullscreen = !isFullscreen);
    } catch (_) {
      // Fullscreen is a convenience; ignore platform failures.
    }
  }

  Future<void> _handleEscape() async {
    if (_fullscreen) {
      await _toggleFullscreen();
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _loadSubtitle() async {
    const group = XTypeGroup(
      label: '字幕',
      extensions: ['srt', 'ass', 'ssa', 'vtt', 'sub'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    await _controller.loadSubtitleFile(file.path);
  }

  Future<void> _takeScreenshot() async {
    final path = await _controller.takeScreenshot();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(path == null ? '截图失败' : '截图已保存：$path'),
          behavior: SnackBarBehavior.floating,
          width: 480,
          backgroundColor: StillColors.surfaceHigh,
        ),
      );
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.space): _controller.togglePlay,
    const SingleActivator(LogicalKeyboardKey.keyK): _controller.togglePlay,
    const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
    ): () => _controller.seekBy(const Duration(seconds: -10)),
    const SingleActivator(
      LogicalKeyboardKey.arrowRight,
    ): () => _controller.seekBy(const Duration(seconds: 10)),
    const SingleActivator(
      LogicalKeyboardKey.keyJ,
    ): () => _controller.seekBy(const Duration(seconds: -10)),
    const SingleActivator(
      LogicalKeyboardKey.keyL,
    ): () => _controller.seekBy(const Duration(seconds: 10)),
    const SingleActivator(
      LogicalKeyboardKey.arrowUp,
    ): () => _controller.setVolume(
      (_controller.volume + 5).clamp(0.0, 100.0).toDouble(),
    ),
    const SingleActivator(
      LogicalKeyboardKey.arrowDown,
    ): () => _controller.setVolume(
      (_controller.volume - 5).clamp(0.0, 100.0).toDouble(),
    ),
    const SingleActivator(LogicalKeyboardKey.keyM): _controller.toggleMute,
    const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
    const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
    const SingleActivator(LogicalKeyboardKey.keyS): () {
      unawaited(_settings.setSubtitlesVisible(!_settings.subtitlesVisible));
    },
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
            onHover: (_) => _showControls(),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildVideo(),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _controller.togglePlay();
                          _showControls();
                        },
                      ),
                    ),
                    _buildTopBar(),
                    _buildBottomControls(),
                    if (_controller.buffering && _controller.playing)
                      const Center(
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    if (_controller.error != null) _buildError(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Video(
      key: _videoKey,
      controller: _controller.videoController,
      controls: (state) => const SizedBox.shrink(),
      fit: BoxFit.contain,
      fill: Colors.black,
      subtitleViewConfiguration: SubtitleViewConfiguration(
        visible: _settings.subtitlesVisible,
        style: TextStyle(
          fontSize: _settings.subtitleFontSize,
          height: 1.35,
          color: Colors.white,
          fontWeight: FontWeight.w500,
          backgroundColor: Colors.black.withValues(alpha: 0.55),
        ),
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 104),
      ),
    );
  }

  Widget _buildTopBar() {
    final item = _controller.current;
    final total = _controller.queue.length;
    final width = _controller.videoWidth;
    final height = _controller.videoHeight;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 26),
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
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item?.name ?? '正在打开…',
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
                        [
                          if (total > 1)
                            '${_controller.index + 1} / $total',
                          if (width != null && height != null)
                            '$width × $height',
                          if (_controller.rate != 1) '${_controller.rate}x',
                        ].join('  ·  '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: MouseRegion(
            onEnter: (_) => _setPointerOverControls(true),
            onExit: (_) => _setPointerOverControls(false),
            child: VideoControls(
              controller: _controller,
              subtitlesVisible: _settings.subtitlesVisible,
              onToggleSubtitles: () {
                unawaited(
                  _settings.setSubtitlesVisible(!_settings.subtitlesVisible),
                );
              },
              onLoadSubtitle: () => unawaited(_loadSubtitle()),
              onScreenshot: () => unawaited(_takeScreenshot()),
              onToggleFullscreen: () => unawaited(_toggleFullscreen()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: StillColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: StillColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: StillColors.danger,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              _controller.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: StillColors.text),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    unawaited(
                      _controller.openQueue(
                        widget.items,
                        _controller.index,
                      ),
                    );
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
