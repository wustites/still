import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/settings_repository.dart';

/// User preferences, loaded once at startup and written through on change.
///
/// Values are intentionally simple: the player reads them when a file is
/// opened, so changes apply immediately or on the next playback.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository) {
    unawaited(_load());
  }

  final SettingsRepository _repository;

  static const _kVolume = 'playback.volume';
  static const _kResume = 'playback.resume';
  static const _kHardwareDecoding = 'playback.hardware_decoding';
  static const _kSubtitleSize = 'subtitle.font_size';
  static const _kSubtitleVisible = 'subtitle.visible';

  double _volume = 100;
  bool _resumePlayback = true;
  bool _hardwareDecoding = true;
  double _subtitleFontSize = 34;
  bool _subtitlesVisible = true;
  bool _loaded = false;
  bool _disposed = false;

  double get volume => _volume;
  bool get resumePlayback => _resumePlayback;
  bool get hardwareDecoding => _hardwareDecoding;
  double get subtitleFontSize => _subtitleFontSize;
  bool get subtitlesVisible => _subtitlesVisible;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _repository.read(_kVolume),
        _repository.read(_kResume),
        _repository.read(_kHardwareDecoding),
        _repository.read(_kSubtitleSize),
        _repository.read(_kSubtitleVisible),
      ]);
      _volume = double.tryParse(values[0] ?? '') ?? _volume;
      _resumePlayback = values[1] == null ? _resumePlayback : values[1] == '1';
      _hardwareDecoding = values[2] == null
          ? _hardwareDecoding
          : values[2] == '1';
      _subtitleFontSize =
          double.tryParse(values[3] ?? '') ?? _subtitleFontSize;
      _subtitlesVisible = values[4] == null
          ? _subtitlesVisible
          : values[4] == '1';
    } finally {
      _loaded = true;
      _notify();
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 100.0).toDouble();
    _notify();
    await _repository.write(_kVolume, _volume.toStringAsFixed(0));
  }

  Future<void> setResumePlayback(bool value) async {
    _resumePlayback = value;
    _notify();
    await _repository.write(_kResume, value ? '1' : '0');
  }

  Future<void> setHardwareDecoding(bool value) async {
    _hardwareDecoding = value;
    _notify();
    await _repository.write(_kHardwareDecoding, value ? '1' : '0');
  }

  Future<void> setSubtitleFontSize(double value) async {
    _subtitleFontSize = value.clamp(18.0, 64.0).toDouble();
    _notify();
    await _repository.write(
      _kSubtitleSize,
      _subtitleFontSize.toStringAsFixed(0),
    );
  }

  Future<void> setSubtitlesVisible(bool value) async {
    _subtitlesVisible = value;
    _notify();
    await _repository.write(_kSubtitleVisible, value ? '1' : '0');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
