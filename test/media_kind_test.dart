import 'package:flutter_test/flutter_test.dart';
import 'package:still/data/models/media_kind.dart';
import 'package:still/data/models/scanned_file.dart';

void main() {
  group('MediaFormats.kindOf', () {
    test('detects videos case-insensitively', () {
      expect(MediaFormats.kindOf('/movies/Clip.MKV'), MediaKind.video);
      expect(MediaFormats.kindOf(r'C:\Movies\clip.MP4'), MediaKind.video);
    });

    test('detects images', () {
      expect(MediaFormats.kindOf('/photos/a.JPEG'), MediaKind.image);
      expect(MediaFormats.kindOf('/photos/a.webp'), MediaKind.image);
    });

    test('ignores everything else', () {
      expect(MediaFormats.kindOf('/notes/readme.txt'), isNull);
      expect(MediaFormats.kindOf('/movies/poster.jpg.txt'), isNull);
    });
  });

  test('ScannedFile.fromPath derives metadata', () {
    final file = ScannedFile.fromPath(
      '/media/Anime 01.mkv',
      sizeBytes: 1024,
      modifiedAt: DateTime.utc(2026, 1, 2),
    );

    expect(file.name, 'Anime 01.mkv');
    expect(file.extension, '.mkv');
    expect(file.kind, MediaKind.video);
  });
}
