import 'dart:ui' show FontFeature;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/format.dart';
import '../../../ui/theme.dart';
import '../player_controller.dart';

class VideoControls extends StatelessWidget {
  const VideoControls({
    super.key,
    required this.controller,
    required this.subtitlesVisible,
    required this.onToggleSubtitles,
    required this.onLoadSubtitle,
    required this.onScreenshot,
    required this.onToggleFullscreen,
  });

  final PlayerController controller;
  final bool subtitlesVisible;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onLoadSubtitle;
  final VoidCallback onScreenshot;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final tracks = controller.tracks;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xE6000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeekBar(controller: controller),
          const SizedBox(height: 2),
          Row(
            children: [
              _IconButton(
                icon: controller.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 26,
                tooltip: controller.playing ? '暂停 (Space)' : '播放 (Space)',
                onPressed: controller.togglePlay,
              ),
              _IconButton(
                icon: Icons.skip_previous_rounded,
                tooltip: '上一个',
                onPressed: controller.hasPrevious ? controller.previous : null,
              ),
              _IconButton(
                icon: Icons.skip_next_rounded,
                tooltip: '下一个',
                onPressed: controller.hasNext ? controller.next : null,
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: controller.volume <= 0.5
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                tooltip: '静音 (M)',
                onPressed: controller.toggleMute,
              ),
              SizedBox(
                width: 104,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: 100,
                    value: controller.volume.clamp(0.0, 100.0).toDouble(),
                    onChanged: (value) => controller.setVolume(value),
                  ),
                ),
              ),
              const Spacer(),
              _SubtitleMenu(
                controller: controller,
                subtitlesVisible: subtitlesVisible,
                onToggleSubtitles: onToggleSubtitles,
                onLoadSubtitle: onLoadSubtitle,
              ),
              _AudioMenu(controller: controller),
              _SpeedMenu(controller: controller),
              _IconButton(
                icon: Icons.photo_camera_outlined,
                tooltip: '截图',
                onPressed: onScreenshot,
              ),
              _IconButton(
                icon: Icons.fullscreen_rounded,
                tooltip: '全屏 (F)',
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.controller});

  final PlayerController controller;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.controller.duration.inMilliseconds;
    final max = durationMs > 0 ? durationMs.toDouble() : 1.0;

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.controller.position,
      builder: (context, position, _) {
        final current = _dragValue ?? position.inMilliseconds.toDouble();
        final safeValue = current.clamp(0.0, max).toDouble();
        return Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                formatDuration(Duration(milliseconds: safeValue.round())),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white70,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: StillColors.accent,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: StillColors.accent,
                ),
                child: Slider(
                  min: 0,
                  max: max,
                  value: safeValue,
                  onChangeStart: (value) =>
                      setState(() => _dragValue = value),
                  onChanged: (value) => setState(() => _dragValue = value),
                  onChangeEnd: (value) {
                    setState(() => _dragValue = null);
                    widget.controller.seekTo(
                      Duration(milliseconds: value.round()),
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                formatDuration(widget.controller.duration),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white70,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubtitleMenu extends StatelessWidget {
  const _SubtitleMenu({
    required this.controller,
    required this.subtitlesVisible,
    required this.onToggleSubtitles,
    required this.onLoadSubtitle,
  });

  final PlayerController controller;
  final bool subtitlesVisible;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onLoadSubtitle;

  @override
  Widget build(BuildContext context) {
    final tracks = controller.tracks.subtitle;
    final current = controller.track.subtitle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconButton(
          icon: subtitlesVisible
              ? Icons.subtitles_rounded
              : Icons.subtitles_off_rounded,
          tooltip: subtitlesVisible ? '隐藏字幕' : '显示字幕',
          onPressed: onToggleSubtitles,
        ),
        PopupMenuButton<String>(
          tooltip: '字幕',
          onSelected: (value) {
            if (value == 'load') {
              onLoadSubtitle();
              return;
            }
            if (value == 'off') {
              controller.setSubtitleTrack(SubtitleTrack.no());
              return;
            }
            final track = tracks.where((t) => t.id == value).firstOrNull;
            if (track != null) controller.setSubtitleTrack(track);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'load', child: Text('加载字幕文件…')),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'off',
              child: Row(
                children: [
                  Icon(
                    current.id == 'no'
                        ? Icons.check_rounded
                        : Icons.subtitles_off_rounded,
                    size: 15,
                    color: StillColors.muted,
                  ),
                  const SizedBox(width: 8),
                  const Text('关闭字幕'),
                ],
              ),
            ),
            for (final track in tracks)
              if (track.id != 'no' && track.id != 'auto')
                PopupMenuItem(
                  value: track.id,
                  child: Row(
                    children: [
                      Icon(
                        current.id == track.id
                            ? Icons.check_rounded
                            : Icons.subtitles_outlined,
                        size: 15,
                        color: current.id == track.id
                            ? StillColors.accent
                            : StillColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _trackLabel(track, '字幕'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Icon(
              Icons.closed_caption_outlined,
              size: 19,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _AudioMenu extends StatelessWidget {
  const _AudioMenu({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final tracks = controller.tracks.audio;
    final current = controller.track.audio;

    return PopupMenuButton<String>(
      tooltip: '音轨',
      onSelected: (value) {
        final track = tracks.where((t) => t.id == value).firstOrNull;
        if (track != null) controller.setAudioTrack(track);
      },
      itemBuilder: (context) => [
        for (final track in tracks)
          if (track.id != 'auto' && track.id != 'no')
            PopupMenuItem(
              value: track.id,
              child: Row(
                children: [
                  Icon(
                    current.id == track.id
                        ? Icons.check_rounded
                        : Icons.graphic_eq_rounded,
                    size: 15,
                    color: current.id == track.id
                        ? StillColors.accent
                        : StillColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _trackLabel(track, '音轨'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(
          Icons.audiotrack_rounded,
          size: 19,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.controller});

  final PlayerController controller;

  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: '播放速度',
      initialValue: controller.rate,
      onSelected: controller.setRate,
      itemBuilder: (context) => [
        for (final speed in speeds)
          PopupMenuItem(
            value: speed,
            child: Row(
              children: [
                Icon(
                  (controller.rate - speed).abs() < 0.01
                      ? Icons.check_rounded
                      : Icons.speed_rounded,
                  size: 15,
                  color: (controller.rate - speed).abs() < 0.01
                      ? StillColors.accent
                      : StillColors.muted,
                ),
                const SizedBox(width: 8),
                Text('${speed}x'),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          '${controller.rate}x',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: size,
      color: Colors.white,
      disabledColor: Colors.white30,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(icon),
    );
  }
}

String _trackLabel(dynamic track, String fallback) {
  final title = track.title as String?;
  final language = track.language as String?;
  if (title != null && title.isNotEmpty) return title;
  if (language != null && language.isNotEmpty) return language;
  return '$fallback ${track.id}';
}
