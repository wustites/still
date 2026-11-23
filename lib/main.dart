import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before any Player is created; loads libmpv on desktop.
  MediaKit.ensureInitialized();

  final database = AppDatabase();
  final library = LibraryRepository(database);
  final settings = SettingsRepository(database);

  runApp(
    StillApp(
      database: database,
      library: library,
      settingsRepository: settings,
    ),
  );
}
