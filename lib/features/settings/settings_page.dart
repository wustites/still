import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_paths.dart';
import '../../ui/theme.dart';
import 'settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: StillColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('设置', style: TextStyle(fontSize: 16)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: StillColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        children: [
          _Section(
            title: '播放',
            children: [
              _SwitchRow(
                title: '硬件解码',
                subtitle: '使用 GPU 解码（mpv hwdec=auto）。修改后对下一次播放生效。',
                value: settings.hardwareDecoding,
                onChanged: settings.setHardwareDecoding,
              ),
              _SwitchRow(
                title: '继续上次播放',
                subtitle: '重新打开视频时，从上次离开的位置继续。',
                value: settings.resumePlayback,
                onChanged: settings.setResumePlayback,
              ),
              _SliderRow(
                title: '默认音量',
                valueLabel: '${settings.volume.round()}%',
                value: settings.volume,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: settings.setVolume,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _Section(
            title: '字幕',
            children: [
              _SwitchRow(
                title: '显示字幕',
                subtitle: '关闭后仍保留已选择的字幕轨，视频中按 S 可快速切换。',
                value: settings.subtitlesVisible,
                onChanged: settings.setSubtitlesVisible,
              ),
              _SliderRow(
                title: '字号',
                valueLabel: '${settings.subtitleFontSize.round()}',
                value: settings.subtitleFontSize,
                min: 18,
                max: 64,
                divisions: 23,
                onChanged: settings.setSubtitleFontSize,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _Section(
            title: '存储',
            children: [
              _PathRow(
                title: '缩略图缓存',
                subtitle: '视频封面帧，可随时删除，Still 会重新生成。',
                path: AppPaths.thumbnailDirectory,
              ),
              _PathRow(
                title: '截图目录',
                subtitle: '播放器中截图保存的位置。',
                path: AppPaths.screenshotDirectory,
              ),
            ],
          ),
          const SizedBox(height: 26),
          const _Section(
            title: '关于',
            children: [
              _InfoRow(title: 'Still', value: '0.1.0'),
              _InfoRow(title: '播放引擎', value: 'libmpv / media_kit'),
              _InfoRow(title: '界面', value: 'Flutter · Material 3'),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: StillColors.muted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: StillColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StillColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: StillColors.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: StillColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(title, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: StillColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final String title;
  final String subtitle;
  final Future<dynamic> Function() path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: StillColors.muted,
                  ),
                ),
                const SizedBox(height: 5),
                FutureBuilder<dynamic>(
                  future: path(),
                  builder: (context, snapshot) {
                    final value = snapshot.data;
                    final text = value == null
                        ? '…'
                        : value.path.toString();
                    return SelectableText(
                      text,
                      style: const TextStyle(
                        fontSize: 11,
                        color: StillColors.muted,
                      ),
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
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: StillColors.muted),
          ),
        ],
      ),
    );
  }
}
