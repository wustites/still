import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/library_repository.dart';
import '../settings/settings_controller.dart';

/// Thin wrapper around media_kit that owns queue state, resume points and the
/// playback-state persistence loop.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required LibraryRepository repository,
    required SettingsController settings,
  }) : _repository = repository,
       _settings = settings {
    _player = Player(
      configuration: const PlayerConfiguration(title: 'Still'),
    );
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: settings.hardwareDecoding,
        hwdec: settings.hardwareDecoding ? 'auto' : 'no',
      ),
    );
    _bind();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_playing) unawaited(_savePosition());
    });
  }

  final LibraryRepository _repository;
  final SettingsController _settings;

  late final Player _player;
  late final VideoController _videoController;

  Player get player => _player;
  VideoController get videoController => _videoController;

  /// High-frequency position updates. Kept separate from [notifyListeners] so
  /// the seek bar can rebuild without rebuilding the video surface.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;

  List<MediaItem> _queue = const [];
  int _index = 0;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  double _volume = 100;
  double _rate = 1;
  double _lastAudibleVolume = 100;
  bool _disposed = false;
  bool _advancing = false;
  int _openToken = 0;
  String? _error;
  bool _mediaLoaded = false;
  int? _durationSavedFor;
  int? _dimensionsSavedFor;

  List<MediaItem> get queue => _queue;
  int get index => _index;
  MediaItem? get current => _queue.isEmpty ? null : _queue[_index];
  bool get hasPrevious => _index > 0;
  bool get hasNext => _index + 1 < _queue.length;
  Duration get duration => _duration;
  bool get playing => _playing;
  bool get buffering => _buffering;
  double get volume => _volume;
  double get rate => _rate;
  String? get error => _error;
  int? get videoWidth => _player.state.width;
  int? get videoHeight => _player.state.height;
  Tracks get tracks => _player.state.tracks;
  Track get track => _player.state.track;
  bool get subtitlesVisible => _settings.subtitlesVisible;

  void _bind() {
    _subscriptions.add(
      _player.stream.playing.listen((value) {
        _playing = value;
        if (!value) unawaited(_savePosition());
        _notify();
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) => position.value = value),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        if (value == _duration) return;
        _duration = value;
        _notify();
        if (value > Duration.zero && _mediaLoaded) {
          unawaited(_saveDurationIfReady());
        }
      }),
    );
    _subscriptions.add(
      _player.stream.width.listen((value) {
        if (value != null && _mediaLoaded) {
          unawaited(_saveDimensionsIfReady());
        }
      }),
    );
    _subscriptions.add(
      _player.stream.height.listen((value) {
        if (value != null && _mediaLoaded) {
          unawaited(_saveDimensionsIfReady());
        }
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((value) {
        if (value == _buffering) return;
        _buffering = value;
        _notify();
      }),
    );
    _subscriptions.add(
      _player.stream.volume.listen((value) {
        _volume = value;
        _notify();
      }),
    );
    _subscriptions.add(
      _player.stream.rate.listen((value) {
        _rate = value;
        _notify();
      }),
    );
    _subscriptions.add(_player.stream.track.listen((_) => _notify()));
    _subscriptions.add(_player.stream.tracks.listen((_) => _notify()));
    _subscriptions.add(
      _player.stream.completed.listen((done) {
        if (done) unawaited(_handleCompleted());
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((message) {
        _error = message;
        _notify();
      }),
    );
  }

  Future<void> openQueue(List<MediaItem> items, int initialIndex) async {
    if (items.isEmpty) return;
    _queue = List<MediaItem>.unmodifiable(items);
    _index = initialIndex.clamp(0, _queue.length - 1).toInt();
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final item = current;
    if (item == null) return;

    final token = ++_openToken;
    _mediaLoaded = false;
    _error = null;
    _duration = Duration.zero;
    position.value = Duration.zero;
    _notify();

    try {
      await _player.open(Media(Uri.file(item.path).toString()), play: true);
      if (_disposed || token != _openToken) return;

      _mediaLoaded = true;
      await _player.setVolume(_settings.volume);
      _lastAudibleVolume = _settings.volume > 0 ? _settings.volume : 100;
      await _repository.markPlayed(item.id);
      unawaited(_saveDurationIfReady());
      unawaited(_saveDimensionsIfReady());

      if (_settings.resumePlayback &&
          item.positionMs > const Duration(seconds: 3).inMilliseconds) {
        unawaited(
          _seekWhenReady(token, Duration(milliseconds: item.positionMs)),
        );
      }
    } catch (error) {
      if (_disposed) return;
      _error = '无法打开文件：$error';
      _notify();
    }
  }

  Future<void> _seekWhenReady(int token, Duration target) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (_disposed || token != _openToken) return;
      final known = _duration > Duration.zero
          ? _duration
          : _player.state.duration;
      if (known > Duration.zero) {
        if (target < known - const Duration(seconds: 5)) {
          await _player.seek(target);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> togglePlay() => _player.playOrPause();

  Future<void> pause() => _player.pause();

  Future<void> seekTo(Duration target) async {
    var value = target;
    if (value < Duration.zero) value = Duration.zero;
    if (_duration > Duration.zero && value > _duration) value = _duration;
    position.value = value;
    await _player.seek(value);
  }

  Future<void> seekBy(Duration delta) async {
    var target = position.value + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await seekTo(target);
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 100.0).toDouble();
    if (clamped > 0) _lastAudibleVolume = clamped;
    await _player.setVolume(clamped);
  }

  Future<void> toggleMute() async {
    if (_volume > 0.5) {
      await setVolume(0);
    } else {
      await setVolume(_lastAudibleVolume);
    }
  }

  Future<void> setRate(double value) async {
    await _player.setRate(value.clamp(0.25, 4.0).toDouble());
  }

  Future<void> setAudioTrack(AudioTrack track) =>
      _player.setAudioTrack(track);

  Future<void> setSubtitleTrack(SubtitleTrack track) =>
      _player.setSubtitleTrack(track);

  Future<void> setVideoTrack(VideoTrack track) =>
      _player.setVideoTrack(track);

  Future<void> loadSubtitleFile(String path) async {
    try {
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(path, title: p.basename(path)),
      );
    } catch (error) {
      _error = '字幕加载失败：$error';
      _notify();
    }
  }

  Future<void> next() async {
    if (!hasNext) return;
    await _savePosition();
    _index++;
    await _loadCurrent();
  }

  Future<void> previous() async {
    if (position.value > const Duration(seconds: 3)) {
      await seekTo(Duration.zero);
      return;
    }
    if (!hasPrevious) {
      await seekTo(Duration.zero);
      return;
    }
    await _savePosition();
    _index--;
    await _loadCurrent();
  }

  Future<void> _handleCompleted() async {
    if (_advancing || _disposed) return;
    _advancing = true;
    try {
      if (hasNext) {
        await next();
      } else {
        await _savePosition();
        await _player.pause();
      }
    } finally {
      _advancing = false;
    }
  }

  Future<String?> takeScreenshot() async {
    try {
      final bytes = await _player.screenshot(format: 'image/png');
      if (bytes == null) return null;
      final directory = await AppPaths.screenshotDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_'
          '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final file = File(p.join(directory.path, 'still_$stamp.png'));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDurationIfReady() async {
    if (!_mediaLoaded) return;
    final item = current;
    if (item == null ||
        _duration <= Duration.zero ||
        _durationSavedFor == item.id) {
      return;
    }
    _durationSavedFor = item.id;
    try {
      await _repository.saveDuration(item, _duration);
    } catch (_) {
      _durationSavedFor = null;
    }
  }

  Future<void> _saveDimensionsIfReady() async {
    if (!_mediaLoaded) return;
    final item = current;
    final width = _player.state.width;
    final height = _player.state.height;
    if (item == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        _dimensionsSavedFor == item.id) {
      return;
    }
    _dimensionsSavedFor = item.id;
    try {
      await _repository.saveDimensions(item, width, height);
    } catch (_) {
      _dimensionsSavedFor = null;
    }
  }

  Future<void> _savePosition() async {
    final item = current;
    if (item == null) return;
    // Ignore the initial `playing = false` emitted while a file is loading:
    // duration and position are both still zero there.
    if (_duration <= Duration.zero && position.value <= Duration.zero) return;
    var value = position.value;
    if (_duration > Duration.zero &&
        value >= _duration - const Duration(seconds: 2)) {
      value = Duration.zero;
    }
    if (value < Duration.zero) value = Duration.zero;
    try {
      await _repository.savePosition(item.id, value);
    } catch (_) {
      // A closed database while the app is shutting down is not actionable.
    }
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      super.dispose();
      return;
    }
    _disposed = true;
    _saveTimer?.cancel();
    unawaited(_savePosition());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    position.dispose();
    super.dispose();
  }
}
