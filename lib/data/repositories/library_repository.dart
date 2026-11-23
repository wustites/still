import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import '../models/media_filter.dart';
import '../models/media_kind.dart';
import '../models/scanned_file.dart';

/// All reads and writes the library UI needs. Keeping drift out of widgets
/// means the storage layer can be swapped (or moved to an isolate) later.
class LibraryRepository {
  LibraryRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Roots
  // ---------------------------------------------------------------------------

  Stream<List<LibraryRoot>> watchRoots() {
    final query = _db.select(_db.libraryRoots)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  Future<LibraryRoot?> rootById(int id) {
    return (_db.select(
      _db.libraryRoots,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<LibraryRoot> addRoot(String path) async {
    final existing = await (_db.select(
      _db.libraryRoots,
    )..where((t) => t.path.equals(path))).getSingleOrNull();
    if (existing != null) return existing;

    final name = p.basename(path);
    final id = await _db
        .into(_db.libraryRoots)
        .insert(
          LibraryRootsCompanion.insert(
            path: path,
            name: name.isEmpty ? path : name,
          ),
        );
    return (await rootById(id))!;
  }

  Future<void> removeRoot(int id) async {
    await (_db.delete(
      _db.libraryRoots,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<LibraryRoot?> findRootByPath(String path) {
    return (_db.select(
      _db.libraryRoots,
    )..where((t) => t.path.equals(path))).getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Replaces the scan result for [rootId] in one transaction.
  ///
  /// Existing rows keep their playback state: the upsert only writes metadata
  /// columns and `missing = false`. Rows that were not seen are flagged
  /// missing instead of deleted.
  Future<void> applyScan(int rootId, List<ScannedFile> files) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.mediaItems)
            ..where((t) => t.rootId.equals(rootId)))
          .write(const MediaItemsCompanion(missing: Value(true)));

      if (files.isNotEmpty) {
        final rows = <MediaItemsCompanion>[
          for (final file in files)
            MediaItemsCompanion.insert(
              rootId: rootId,
              path: file.path,
              name: file.name,
              ext: file.extension,
              kind: file.kind,
              sizeBytes: file.sizeBytes,
              modifiedAt: file.modifiedAt,
              missing: const Value(false),
              updatedAt: Value(now),
            ),
        ];
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.mediaItems, rows);
        });
      }

      await (_db.update(_db.libraryRoots)
            ..where((t) => t.id.equals(rootId)))
          .write(LibraryRootsCompanion(lastScanAt: Value(now)));
    });
  }

  // ---------------------------------------------------------------------------
  // Media queries
  // ---------------------------------------------------------------------------

  Stream<List<MediaItem>> watchMedia(MediaFilter filter) {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.missing.equals(false));

    if (filter.rootId != null) {
      query.where((t) => t.rootId.equals(filter.rootId!));
    }
    if (filter.kind != null) {
      query.where((t) => t.kind.equalsValue(filter.kind!));
    }
    if (filter.favoritesOnly) {
      query.where((t) => t.favorite.equals(true));
    }
    if (filter.recentOnly) {
      query.where((t) => t.lastPlayedAt.isNotNull());
    }
    final search = filter.query.trim().toLowerCase();
    if (search.isNotEmpty) {
      query.where((t) => t.name.lower().contains(search));
    }

    switch (filter.sort) {
      case MediaSort.name:
        query.orderBy([(t) => OrderingTerm.asc(t.name)]);
        break;
      case MediaSort.modified:
        query.orderBy([(t) => OrderingTerm.desc(t.modifiedAt)]);
        break;
      case MediaSort.added:
        query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
        break;
      case MediaSort.duration:
        query.orderBy([(t) => OrderingTerm.desc(t.durationMs)]);
        break;
      case MediaSort.lastPlayed:
        query.orderBy([(t) => OrderingTerm.desc(t.lastPlayedAt)]);
        break;
    }

    if (filter.limit != null) {
      query.limit(filter.limit!);
    }
    return query.watch();
  }

  Future<MediaItem?> mediaById(int id) {
    return (_db.select(
      _db.mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Videos that still lack a generated poster frame, newest first.
  Future<List<MediaItem>> itemsNeedingThumbnails({int limit = 200}) {
    final query = _db.select(_db.mediaItems)
      ..where(
        (t) =>
            t.kind.equalsValue(MediaKind.video) &
            t.thumbnailPath.isNull() &
            t.missing.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.modifiedAt)])
      ..limit(limit);
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Playback state
  // ---------------------------------------------------------------------------

  /// Called once when a file starts playing.
  Future<void> markPlayed(int id) async {
    final item = await mediaById(id);
    if (item == null) return;
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        playCount: Value(item.playCount + 1),
        lastPlayedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Periodic checkpoint; cheap enough to run every few seconds.
  Future<void> savePosition(int id, Duration position) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        positionMs: Value(position.inMilliseconds),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        favorite: Value(favorite),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setThumbnail(int id, String path) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(thumbnailPath: Value(path)),
    );
  }

  // ---------------------------------------------------------------------------
  // Playlists (storage only; the UI arrives in a later milestone)
  // ---------------------------------------------------------------------------

  Stream<List<Playlist>> watchPlaylists() {
    final query = _db.select(_db.playlists)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  Future<int> createPlaylist(String name) {
    return _db
        .into(_db.playlists)
        .insert(PlaylistsCompanion.insert(name: name));
  }

  Future<void> addToPlaylist(int playlistId, int mediaId) async {
    final count = _db.playlistItems.id.count();
    final row =
        await (_db.selectOnly(_db.playlistItems)
              ..addColumns([count])
              ..where(_db.playlistItems.playlistId.equals(playlistId)))
            .getSingle();
    await _db
        .into(_db.playlistItems)
        .insert(
          PlaylistItemsCompanion.insert(
            playlistId: playlistId,
            mediaId: mediaId,
            sortOrder: Value(row.read(count) ?? 0),
          ),
        );
  }

  Stream<List<MediaItem>> watchPlaylistItems(int playlistId) {
    final query = _db.select(_db.playlistItems).join([
      innerJoin(
        _db.mediaItems,
        _db.mediaItems.id.equalsExp(_db.playlistItems.mediaId),
      ),
    ])
      ..where(_db.playlistItems.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(_db.playlistItems.sortOrder)]);

    return query.watch().map(
      (rows) => [for (final row in rows) row.readTable(_db.mediaItems)],
    );
  }
}
