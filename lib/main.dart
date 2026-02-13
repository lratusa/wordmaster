import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'src/core/database/database_helper.dart';
import 'src/core/constants/app_constants.dart';
import 'src/features/word_lists/data/repositories/word_list_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize platform-specific database factory
  DatabaseHelper.initializePlatform();

  // Initialize database
  await DatabaseHelper.instance.database;

  // Clean up any duplicate word lists and import built-in ones
  final wordListRepo = WordListRepository();
  await wordListRepo.removeDuplicateWordLists();
  await wordListRepo.importBuiltInWordLists();

  // Configure desktop window
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(AppConstants.desktopDefaultWidth, AppConstants.desktopDefaultHeight),
      minimumSize: Size(AppConstants.desktopMinWidth, AppConstants.desktopMinHeight),
      center: true,
      title: AppConstants.appName,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: WordMasterApp(),
    ),
  );
}
