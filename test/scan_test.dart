import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:still/data/db/app_database.dart';
import 'package:still/data/models/media_filter.dart';
import 'package:still/data/models/scanned_file.dart';
import 'package:still/data/repositories/library_repository.dart';
import 'package:still/services/scan/scan_service.dart';
import 'package:still/services/thumbnails/thumbnail_service.dart';

ScanResult result(List<ScannedFile> files, {int errors = 0}) =>
    ScanResult(files: files, errors: errors, elapsed: Duration.zero);

void main() {
  late LibraryRepository repository;
  late Directory directory;
  late LibraryRoot root;

  setUp(() async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    repository = LibraryRepository(database);
    directory = await Directory.systemTemp.createTemp('still_scan_test_');
    addTearDown(() => directory.delete(recursive: true));
    root = await repository.addRoot(directory.path);
  });

  test(
    'partial scan indexes readable files and preserves unseen entries',
    () async {
      ScannedFile file(String name) => ScannedFile.fromPath(
        p.join(directory.path, name),
        sizeBytes: 1,
        modifiedAt: DateTime.utc(2026),
      );
      final old = file('old.jpg');
      final fresh = file('new.jpg');
      final filter = MediaFilter(rootId: root.id);

      await repository.applyScan(root.id, result([old]));
      final original = (await repository.watchMedia(filter).first).single;
      await repository.setFavorite(original.id, true);
      final lastCompleteScan = (await repository.rootById(root.id))!.lastScanAt;
      expect(lastCompleteScan, isNotNull);

      await repository.applyScan(root.id, result([fresh], errors: 1));
      final visible = await repository.watchMedia(filter).first;
      expect(
        visible.map((item) => item.path),
        unorderedEquals([old.path, fresh.path]),
      );
      expect(
        (await repository.rootById(root.id))!.lastScanAt,
        lastCompleteScan,
      );

      await repository.applyScan(root.id, result([fresh]));
      expect(
        (await repository.watchMedia(filter).first).single.path,
        fresh.path,
      );
      final retained = (await repository.mediaById(original.id))!;
      expect(retained.missing, isTrue);
      expect(retained.favorite, isTrue);
    },
  );

  test('rescans clear derived metadata only when the file changes', () async {
    final path = p.join(directory.path, 'clip.mp4');
    final modifiedAt = DateTime.utc(2026);
    ScannedFile file(int size) =>
        ScannedFile.fromPath(path, sizeBytes: size, modifiedAt: modifiedAt);
    final filter = MediaFilter(rootId: root.id);

    await repository.applyScan(root.id, result([file(10)]));
    final original = (await repository.watchMedia(filter).first).single;
    await repository.setFavorite(original.id, true);
    await repository.setThumbnail(original, 'poster.jpg');
    await repository.saveDuration(original, const Duration(seconds: 3));
    await repository.saveDimensions(original, 640, 480);

    await repository.applyScan(root.id, result([file(10)]));
    expect(
      (await repository.mediaById(original.id))!.thumbnailPath,
      'poster.jpg',
    );

    await repository.applyScan(root.id, result([file(20)]));
    await repository.setThumbnail(original, 'outdated.jpg');
    final replaced = (await repository.mediaById(original.id))!;
    expect(replaced.thumbnailPath, isNull);
    expect(replaced.durationMs, isNull);
    expect(replaced.width, isNull);
    expect(replaced.height, isNull);
    expect(replaced.favorite, isTrue);
  });

  test(
    'cancelling a scan discards its result and keeps the scan slot',
    () async {
      await File(p.join(directory.path, 'photo.jpg')).writeAsBytes([0]);
      final service = ScanService(
        repository: repository,
        thumbnails: ThumbnailService(repository),
      );
      addTearDown(service.dispose);

      final started = Completer<void>();
      service.addListener(() {
        if (service.currentRoot != null && !started.isCompleted) {
          started.complete();
        }
      });
      final running = service.scanRoot(root);
      await started.future;
      await service.cancel();
      expect(service.scanning, isTrue);
      await service.scanAll();
      await running;

      expect(service.scanning, isFalse);
      expect(service.lastResult, isNull);
      expect((await repository.rootById(root.id))!.lastScanAt, isNull);
      expect(
        await repository.watchMedia(MediaFilter(rootId: root.id)).first,
        isEmpty,
      );
    },
  );
}
