import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';

class SettingsRepository {
  Future<dynamic> get _db async => DatabaseHelper.instance.database;

  /// Get a setting value by key, returns null if not found.
  Future<String?> get(String key) async {
    final db = await _db;
    final results = await db.query(
      DbConstants.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String;
  }

  /// Set a setting value (insert or update).
  Future<void> set(String key, String value) async {
    final db = await _db;
    await db.insert(
      DbConstants.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a setting.
  Future<void> delete(String key) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Get all settings as a map.
  Future<Map<String, String>> getAll() async {
    final db = await _db;
    final results = await db.query(DbConstants.tableSettings);
    return {
      for (final row in results)
        row['key'] as String: row['value'] as String,
    };
  }
}

/// Setting keys used throughout the app.
class SettingKeys {
  SettingKeys._();

  static const String aiBackend = 'ai_backend'; // openai, deepseek, ollama, manual
  static const String apiKey = 'api_key';
  static const String ollamaUrl = 'ollama_url';
  static const String ollamaModel = 'ollama_model';
  static const String ttsSpeed = 'tts_speed';
  static const String themeMode = 'theme_mode'; // system, light, dark
  static const String dailyNewWordsGoal = 'daily_new_words_goal';
  static const String dailyReviewLimit = 'daily_review_limit';
}
