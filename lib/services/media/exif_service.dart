import 'dart:io';

import 'package:exif/exif.dart';

/// Reads a small, curated set of EXIF fields for the image info panel.
abstract final class ExifService {
  static const _fields = <String, String>{
    'Make': '相机品牌',
    'Model': '相机型号',
    'LensModel': '镜头',
    'DateTimeOriginal': '拍摄时间',
    'ExposureTime': '快门',
    'FNumber': '光圈',
    'ISOSpeedRatings': 'ISO',
    'FocalLength': '焦距',
    'FocalLengthIn35mmFilm': '等效焦距',
    'Orientation': '方向',
    'ImageWidth': '宽度',
    'ImageLength': '高度',
  };

  /// Returns display-ready rows in a stable order. Missing tags are omitted.
  static Future<Map<String, String>> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return const {};

    final Map<String, IfdTag> tags;
    try {
      tags = await readExifFromFile(file);
    } catch (_) {
      return const {};
    }

    final result = <String, String>{};
    for (final entry in _fields.entries) {
      final tag = _findTag(tags, entry.key);
      if (tag == null) continue;
      final value = tag.printable.trim();
      if (value.isEmpty || value == 'N/A') continue;
      result[entry.value] = value;
    }
    return result;
  }

  /// exif prefixes keys with the IFD name (`EXIF DateTimeOriginal`,
  /// `Image Make`, ...), so match on the suffix.
  static IfdTag? _findTag(Map<String, IfdTag> tags, String field) {
    final direct = tags[field];
    if (direct != null) return direct;
    for (final entry in tags.entries) {
      if (entry.key.endsWith(' $field')) return entry.value;
    }
    return null;
  }
}
