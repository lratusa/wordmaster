import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/enums/language.dart';
import '../../domain/models/word.dart';
import '../../domain/models/word_list.dart';
import '../datasources/word_list_asset_datasource.dart';

class WordListRepository {
  final _assetDatasource = WordListAssetDatasource();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Get all word lists with progress info
  Future<List<WordList>> getAllWordLists() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT wl.*,
        COALESCE(learned.cnt, 0) as learned_count,
        COALESCE(due.cnt, 0) as review_due_count
      FROM ${DbConstants.tableWordLists} wl
      LEFT JOIN (
        SELECT w.word_list_id, COUNT(*) as cnt
        FROM ${DbConstants.tableWords} w
        INNER JOIN ${DbConstants.tableUserProgress} up ON w.id = up.word_id
        WHERE up.is_new = 0
        GROUP BY w.word_list_id
      ) learned ON wl.id = learned.word_list_id
      LEFT JOIN (
        SELECT w.word_list_id, COUNT(*) as cnt
        FROM ${DbConstants.tableWords} w
        INNER JOIN ${DbConstants.tableUserProgress} up ON w.id = up.word_id
        WHERE up.due_date <= datetime('now') AND up.is_new = 0
        GROUP BY w.word_list_id
      ) due ON wl.id = due.word_list_id
      ORDER BY wl.language, wl.created_at
    ''');

    return results.map(WordList.fromMap).toList();
  }

  /// Get word lists filtered by language
  Future<List<WordList>> getWordListsByLanguage(Language language) async {
    final all = await getAllWordLists();
    return all.where((wl) => wl.language == language).toList();
  }

  /// Get a single word list by ID
  Future<WordList?> getWordListById(int id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT wl.*,
        COALESCE(learned.cnt, 0) as learned_count,
        COALESCE(due.cnt, 0) as review_due_count
      FROM ${DbConstants.tableWordLists} wl
      LEFT JOIN (
        SELECT w.word_list_id, COUNT(*) as cnt
        FROM ${DbConstants.tableWords} w
        INNER JOIN ${DbConstants.tableUserProgress} up ON w.id = up.word_id
        WHERE up.is_new = 0
        GROUP BY w.word_list_id
      ) learned ON wl.id = learned.word_list_id
      LEFT JOIN (
        SELECT w.word_list_id, COUNT(*) as cnt
        FROM ${DbConstants.tableWords} w
        INNER JOIN ${DbConstants.tableUserProgress} up ON w.id = up.word_id
        WHERE up.due_date <= datetime('now') AND up.is_new = 0
        GROUP BY w.word_list_id
      ) due ON wl.id = due.word_list_id
      WHERE wl.id = ?
    ''', [id]);

    if (results.isEmpty) return null;
    return WordList.fromMap(results.first);
  }

  /// Import built-in word lists from JSON assets into SQLite.
  /// Returns the number of new word lists imported.
  Future<int> importBuiltInWordLists() async {
    final db = await _db;
    int imported = 0;

    for (final assetKey in WordListAssetDatasource.availableAssetKeys) {
      // Check if already imported
      final existing = await db.query(
        DbConstants.tableWordLists,
        where: "name = ? AND type = 'built_in'",
        whereArgs: [_getNameForKey(assetKey)],
      );

      if (existing.isNotEmpty) continue;

      // Load from JSON asset
      final data = await _assetDatasource.loadWordListData(assetKey);

      // Insert word list
      final wordListId = await db.insert(
        DbConstants.tableWordLists,
        data.wordList.toMap(),
      );

      // Insert words and example sentences in a batch
      final batch = db.batch();
      for (final word in data.words) {
        batch.insert(
          DbConstants.tableWords,
          word.copyWith(wordListId: wordListId).toMap(),
        );
      }
      final wordIds = await batch.commit();

      // Insert example sentences
      final sentenceBatch = db.batch();
      for (int i = 0; i < data.words.length; i++) {
        final wordId = wordIds[i] as int;
        for (int j = 0; j < data.words[i].exampleSentences.length; j++) {
          final sentence = data.words[i].exampleSentences[j];
          sentenceBatch.insert(
            DbConstants.tableExampleSentences,
            ExampleSentence(
              wordId: wordId,
              sentence: sentence.sentence,
              translationCn: sentence.translationCn,
              sortOrder: j,
            ).toMap(),
          );
        }
      }
      await sentenceBatch.commit();

      imported++;
    }

    return imported;
  }

  String _getNameForKey(String key) {
    switch (key) {
      case 'cet4':
        return 'CET-4 大学英语四级';
      case 'jlpt_n5':
        return 'JLPT N5 基础日语';
      default:
        return key;
    }
  }

  /// Create a custom word list
  Future<int> createWordList(WordList wordList) async {
    final db = await _db;
    return db.insert(DbConstants.tableWordLists, wordList.toMap());
  }

  /// Delete a word list and all its words (cascade)
  Future<void> deleteWordList(int id) async {
    final db = await _db;
    await db.delete(
      DbConstants.tableWordLists,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
