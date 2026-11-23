import 'package:drift/drift.dart';

import '../models/media_kind.dart';

/// A folder the user added to the library.
class LibraryRoots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get lastScanAt => dateTime().nullable()();
}

/// One row per media file on disk.
///
/// `path` is unique and doubles as the scanner's identity for a file. Playback
/// state (`positionMs`, `playCount`, `favorite`) lives here so it survives
/// rescans.
@TableIndex(name: 'media_items_root', columns: {#rootId})
@TableIndex(name: 'media_items_kind', columns: {#kind})
@TableIndex(name: 'media_items_last_played', columns: {#lastPlayedAt})
@TableIndex(name: 'media_items_missing', columns: {#missing})
class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get rootId => integer().references(
    LibraryRoots,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get path => text().unique()();
  TextColumn get name => text()();
  TextColumn get ext => text()();
  TextColumn get kind => textEnum<MediaKind>()();

  IntColumn get sizeBytes => integer()();
  DateTimeColumn get modifiedAt => dateTime()();

  /// Filled in lazily (images: original size; videos: probe result).
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();

  /// Absolute path of a generated poster frame, if one exists.
  TextColumn get thumbnailPath => text().nullable()();

  /// Set when a rescan no longer finds the file. Rows are kept so playback
  /// history is not lost when a drive is unplugged.
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

@TableIndex(name: 'playlist_items_playlist', columns: {#playlistId})
class PlaylistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(
    Playlists,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get mediaId => integer().references(
    MediaItems,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Tiny key/value store for user preferences.
class AppSettings extends Table {
  TextColumn get name => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {name};
}
