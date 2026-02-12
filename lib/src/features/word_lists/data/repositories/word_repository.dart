import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/models/word.dart';

class WordRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Get all words in a word list
  Future<List<Word>> getWordsByListId(int wordListId) async {
    final db = await _db;
    final wordMaps = await db.query(
      DbConstants.tableWords,
      where: 'word_list_id = ?',
      whereArgs: [wordListId],
      orderBy: 'id',
    );

    final words = <Word>[];
    for (final map in wordMaps) {
      final word = Word.fromMap(map);
      final sentences = await _getExampleSentences(db, word.id!);
      words.add(word.copyWith(exampleSentences: sentences));
    }
    return words;
  }

  /// Get a single word by ID with its example sentences
  Future<Word?> getWordById(int id) async {
    final db = await _db;
    final results = await db.query(
      DbConstants.tableWords,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final word = Word.fromMap(results.first);
    final sentences = await _getExampleSentences(db, id);
    return word.copyWith(exampleSentences: sentences);
  }

  /// Search words across all word lists
  Future<List<Word>> searchWords(String query) async {
    if (query.trim().isEmpty) return [];

    final db = await _db;
    final searchTerm = '%$query%';
    final wordMaps = await db.query(
      DbConstants.tableWords,
      where: 'word LIKE ? OR translation_cn LIKE ? OR reading LIKE ?',
      whereArgs: [searchTerm, searchTerm, searchTerm],
      orderBy: 'word',
      limit: 50,
    );

    final words = <Word>[];
    for (final map in wordMaps) {
      final word = Word.fromMap(map);
      final sentences = await _getExampleSentences(db, word.id!);
      words.add(word.copyWith(exampleSentences: sentences));
    }
    return words;
  }

  /// Get words by list ID with pagination
  Future<List<Word>> getWordsByListIdPaginated(
    int wordListId, {
    required int offset,
    required int limit,
  }) async {
    final db = await _db;
    final wordMaps = await db.query(
      DbConstants.tableWords,
      where: 'word_list_id = ?',
      whereArgs: [wordListId],
      orderBy: 'id',
      offset: offset,
      limit: limit,
    );

    final words = <Word>[];
    for (final map in wordMaps) {
      final word = Word.fromMap(map);
      final sentences = await _getExampleSentences(db, word.id!);
      words.add(word.copyWith(exampleSentences: sentences));
    }
    return words;
  }

  /// Get count of words in a word list
  Future<int> getWordCount(int wordListId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableWords} WHERE word_list_id = ?',
      [wordListId],
    );
    return result.first['cnt'] as int;
  }

  /// Add a word to a word list
  Future<int> insertWord(Word word) async {
    final db = await _db;
    final wordId = await db.insert(DbConstants.tableWords, word.toMap());

    // Insert example sentences
    for (int i = 0; i < word.exampleSentences.length; i++) {
      await db.insert(
        DbConstants.tableExampleSentences,
        ExampleSentence(
          wordId: wordId,
          sentence: word.exampleSentences[i].sentence,
          translationCn: word.exampleSentences[i].translationCn,
          sortOrder: i,
        ).toMap(),
      );
    }

    // Update word count
    await _updateWordCount(db, word.wordListId);
    return wordId;
  }

  /// Delete a word
  Future<void> deleteWord(int id) async {
    final db = await _db;
    final word = await getWordById(id);
    if (word == null) return;

    await db.delete(
      DbConstants.tableWords,
      where: 'id = ?',
      whereArgs: [id],
    );

    await _updateWordCount(db, word.wordListId);
  }

  Future<List<ExampleSentence>> _getExampleSentences(
      Database db, int wordId) async {
    final results = await db.query(
      DbConstants.tableExampleSentences,
      where: 'word_id = ?',
      whereArgs: [wordId],
      orderBy: 'sort_order',
    );
    return results.map(ExampleSentence.fromMap).toList();
  }

  Future<void> _updateWordCount(Database db, int wordListId) async {
    final count = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableWords} WHERE word_list_id = ?',
      [wordListId],
    );
    await db.update(
      DbConstants.tableWordLists,
      {'word_count': count.first['cnt'] as int},
      where: 'id = ?',
      whereArgs: [wordListId],
    );
  }
}
