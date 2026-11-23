import '../db/app_database.dart';

/// Key/value preferences backed by the same SQLite file as the library.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> read(String name) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String name, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(name: name, value: value),
        );
  }

  Stream<String?> watch(String name) {
    return (_db.select(
      _db.appSettings,
    )..where((t) => t.name.equals(name))).watchSingleOrNull().map(
      (row) => row?.value,
    );
  }
}
