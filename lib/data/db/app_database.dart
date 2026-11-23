import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/media_kind.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [LibraryRoots, MediaItems, Playlists, PlaylistItems, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'still'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
