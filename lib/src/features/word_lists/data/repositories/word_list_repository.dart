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
      // Load from JSON asset first to get the actual name
      final data = await _assetDatasource.loadWordListData(assetKey);
      final actualName = data.wordList.name;

      // Check if already imported by exact name match
      final existing = await db.query(
        DbConstants.tableWordLists,
        where: "name = ? AND type = 'built_in'",
        whereArgs: [actualName],
      );

      if (existing.isNotEmpty) continue;

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

  /// Remove duplicate built-in word lists, keeping only the first one
  Future<int> removeDuplicateWordLists() async {
    final db = await _db;

    // Find duplicates by name
    final duplicates = await db.rawQuery('''
      SELECT name, COUNT(*) as cnt, MIN(id) as keep_id
      FROM ${DbConstants.tableWordLists}
      WHERE type = 'built_in'
      GROUP BY name
      HAVING COUNT(*) > 1
    ''');

    int removed = 0;
    for (final row in duplicates) {
      final name = row['name'] as String;
      final keepId = row['keep_id'] as int;

      // Delete duplicates (keep the one with smallest id)
      final result = await db.delete(
        DbConstants.tableWordLists,
        where: "name = ? AND type = 'built_in' AND id != ?",
        whereArgs: [name, keepId],
      );
      removed += result;
    }

    return removed;
  }

  /// Reset all word lists - delete everything and reimport built-in lists
  Future<void> resetAllWordLists() async {
    final db = await _db;

    // Delete all word lists (cascade will delete words and sentences)
    await db.delete(DbConstants.tableWordLists);

    // Reimport built-in word lists
    await importBuiltInWordLists();
  }

  /// Import a word list with its words from downloaded package
  Future<int> importWordListWithWords(WordList wordList, List<Word> words) async {
    final db = await _db;

    // Check if already exists
    final existing = await db.query(
      DbConstants.tableWordLists,
      where: "name = ?",
      whereArgs: [wordList.name],
    );

    if (existing.isNotEmpty) {
      // Already exists, skip
      return existing.first['id'] as int;
    }

    // Insert word list
    final wordListId = await db.insert(
      DbConstants.tableWordLists,
      wordList.toMap(),
    );

    // Insert words in batch
    final batch = db.batch();
    for (final word in words) {
      batch.insert(
        DbConstants.tableWords,
        word.copyWith(wordListId: wordListId).toMap(),
      );
    }
    final wordIds = await batch.commit();

    // Insert example sentences
    final sentenceBatch = db.batch();
    for (int i = 0; i < words.length; i++) {
      final wordId = wordIds[i] as int;
      for (int j = 0; j < words[i].exampleSentences.length; j++) {
        final sentence = words[i].exampleSentences[j];
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

    return wordListId;
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
