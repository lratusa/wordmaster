import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/core/database/database_helper.dart';
import 'package:wordmaster/src/core/database/database_tables.dart';

/// Creates a fresh in-memory SQLite database with the full schema.
/// Call this in setUp() for each repository test group.
Future<Database> createTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        // Enable foreign keys
        await db.execute('PRAGMA foreign_keys = ON');

        // Create all tables
        for (final sql in DatabaseTables.allCreateStatements) {
          await db.execute(sql);
        }

        // Create indexes
        for (final sql in DatabaseTables.createIndexes) {
          await db.execute(sql);
        }

        // Insert default achievements
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
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );

  // Inject into DatabaseHelper singleton so repositories use this DB
  await DatabaseHelper.setTestDatabase(db);
  return db;
}

/// Insert a test word list and return its ID.
Future<int> insertTestWordList(
  Database db, {
  String name = 'Test List',
  String language = 'en',
  String type = 'built_in',
  int wordCount = 0,
}) async {
  return db.insert('word_lists', {
    'name': name,
    'language': language,
    'type': type,
    'word_count': wordCount,
  });
}

/// Insert a test word and return its ID.
Future<int> insertTestWord(
  Database db, {
  required int wordListId,
  required String word,
  String translationCn = '翻译',
  String language = 'en',
  String? partOfSpeech,
  String? reading,
  String? onyomi,
  String? kunyomi,
}) async {
  return db.insert('words', {
    'word_list_id': wordListId,
    'word': word,
    'translation_cn': translationCn,
    'language': language,
    'part_of_speech': partOfSpeech,
    'reading': reading,
    'onyomi': onyomi,
    'kunyomi': kunyomi,
  });
}

/// Insert a test example sentence and return its ID.
Future<int> insertTestSentence(
  Database db, {
  required int wordId,
  required String sentence,
  String translationCn = '翻译',
  String? reading,
  int sortOrder = 0,
}) async {
  return db.insert('example_sentences', {
    'word_id': wordId,
    'sentence': sentence,
    'translation_cn': translationCn,
    'reading': reading,
    'sort_order': sortOrder,
  });
}

/// Insert a user_progress row and return its ID.
Future<int> insertTestProgress(
  Database db, {
  required int wordId,
  String fsrsCardJson = '{}',
  String? dueDate,
  int isNew = 1,
  int isStarred = 0,
  int state = 0,
}) async {
  return db.insert('user_progress', {
    'word_id': wordId,
    'fsrs_card_json': fsrsCardJson,
    'due_date': dueDate ?? DateTime.now().toUtc().toIso8601String(),
    'is_new': isNew,
    'is_starred': isStarred,
    'state': state,
  });
}
