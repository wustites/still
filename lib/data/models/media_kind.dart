import 'package:path/path.dart' as p;

/// The two kinds of media Still knows about.
enum MediaKind { video, image }

/// Extension sets and small helpers shared by the scanner and the UI.
abstract final class MediaFormats {
  static const Set<String> video = {
    '.mkv',
    '.mp4',
    '.m4v',
    '.mov',
    '.avi',
    '.webm',
    '.wmv',
    '.flv',
    '.ts',
    '.m2ts',
    '.mts',
    '.mpg',
    '.mpeg',
    '.3gp',
    '.ogv',
    '.rmvb',
    '.rm',
  };

  static const Set<String> image = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.tif',
    '.tiff',
    '.avif',
  };

  static const Set<String> subtitles = {
    '.srt',
    '.ass',
    '.ssa',
    '.vtt',
    '.sub',
  };

  static const Set<String> all = {...video, ...image};

  /// Returns the [MediaKind] for [path], or `null` when the file is not media.
  static MediaKind? kindOf(String path) {
    final extension = p.extension(path).toLowerCase();
    if (video.contains(extension)) return MediaKind.video;
    if (image.contains(extension)) return MediaKind.image;
    return null;
  }
}

extension MediaKindInfo on MediaKind {
  bool get isVideo => this == MediaKind.video;

  String get label => switch (this) {
    MediaKind.video => '视频',
    MediaKind.image => '图片',
  };

  String get pluralLabel => switch (this) {
    MediaKind.video => '视频',
    MediaKind.image => '图片',
  };
}
