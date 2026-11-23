import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db/app_database.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/library/library_page.dart';
import 'features/settings/settings_controller.dart';
import 'services/scan/scan_service.dart';
import 'services/thumbnails/thumbnail_service.dart';
import 'ui/theme.dart';

class StillApp extends StatelessWidget {
  const StillApp({
    super.key,
    required this.database,
    required this.library,
    required this.settingsRepository,
  });

  final AppDatabase database;
  final LibraryRepository library;
  final SettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<LibraryRepository>.value(value: library),
        Provider<SettingsRepository>.value(value: settingsRepository),
        ChangeNotifierProvider(
          create: (_) => SettingsController(settingsRepository),
        ),
        Provider(create: (_) => ThumbnailService(library)),
        ChangeNotifierProvider(
          create: (context) => ScanService(
            repository: library,
            thumbnails: context.read<ThumbnailService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Still',
        debugShowCheckedModeBanner: false,
        theme: buildStillTheme(),
        home: const LibraryPage(),
      ),
    );
  }
}
