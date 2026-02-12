import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/db_constants.dart';
import 'database_tables.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  /// Initialize the database factory based on platform
  static void initializePlatform() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // On mobile, sqflite uses its own default factory
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await _getDatabasePath();
    debugPrint('Database path: $dbPath');

    return await openDatabase(
      dbPath,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<String> _getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, DbConstants.databaseName);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all tables
    for (final sql in DatabaseTables.allCreateStatements) {
      await db.execute(sql);
    }

    // Create indexes
    for (final sql in DatabaseTables.createIndexes) {
      await db.execute(sql);
    }

    // Insert default achievements
    await _insertDefaultAchievements(db);

    debugPrint('Database created successfully with version $version');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Database upgrade from $oldVersion to $newVersion');
    // Future migrations go here
  }

  Future<void> _insertDefaultAchievements(Database db) async {
    final achievements = [
      {'achievement_key': 'first_checkin', 'name': '初学者', 'description': '首次完成打卡', 'icon_name': 'seed', 'target': 1},
      {'achievement_key': 'streak_3', 'name': '三天热身', 'description': '连续打卡3天', 'icon_name': 'fire', 'target': 3},
      {'achievement_key': 'streak_7', 'name': '一周达人', 'description': '连续打卡7天', 'icon_name': 'star', 'target': 7},
      {'achievement_key': 'streak_30', 'name': '月度之星', 'description': '连续打卡30天', 'icon_name': 'trophy', 'target': 30},
      {'achievement_key': 'streak_100', 'name': '百日坚持', 'description': '连续打卡100天', 'icon_name': 'crown', 'target': 100},
      {'achievement_key': 'words_100', 'name': '词汇新手', 'description': '累计学习100词', 'icon_name': 'bronze_medal', 'target': 100},
      {'achievement_key': 'words_500', 'name': '词汇达人', 'description': '累计学习500词', 'icon_name': 'silver_medal', 'target': 500},
      {'achievement_key': 'words_2000', 'name': '词汇大师', 'description': '累计学习2000词', 'icon_name': 'gold_medal', 'target': 2000},
      {'achievement_key': 'bilingual', 'name': '双语学者', 'description': '同时学习英语和日语', 'icon_name': 'globe', 'target': 1},
      {'achievement_key': 'audio_50', 'name': '听力达人', 'description': '完成50次听力训练', 'icon_name': 'headphones', 'target': 50},
    ];

    for (final a in achievements) {
      await db.insert('achievements', a);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
