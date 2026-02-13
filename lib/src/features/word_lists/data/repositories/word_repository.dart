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

  /// Get distractor words for quiz mode.
  /// Fallback logic:
  /// 1. Same word list, same part of speech
  /// 2. Same word list, any part of speech
  /// 3. Other word lists (same language)
  Future<List<Word>> getDistractors({
    required int wordListId,
    required int excludeWordId,
    required String language,
    String? preferPartOfSpeech,
    int count = 3,
  }) async {
    final db = await _db;
    final distractors = <Word>[];
    final excludeIds = <int>{excludeWordId};

    // Step 1: Try same word list, same part of speech
    if (preferPartOfSpeech != null && preferPartOfSpeech.isNotEmpty) {
      final samePosResults = await db.rawQuery('''
        SELECT * FROM ${DbConstants.tableWords}
        WHERE word_list_id = ? AND id NOT IN (${excludeIds.join(',')})
          AND part_of_speech = ?
        ORDER BY RANDOM()
        LIMIT ?
      ''', [wordListId, preferPartOfSpeech, count]);

      for (final map in samePosResults) {
        final word = Word.fromMap(map);
        distractors.add(word);
        excludeIds.add(word.id!);
      }
    }

    // Step 2: If not enough, get from same word list (any part of speech)
    if (distractors.length < count) {
      final needed = count - distractors.length;
      final sameListResults = await db.rawQuery('''
        SELECT * FROM ${DbConstants.tableWords}
        WHERE word_list_id = ? AND id NOT IN (${excludeIds.join(',')})
        ORDER BY RANDOM()
        LIMIT ?
      ''', [wordListId, needed]);

      for (final map in sameListResults) {
        final word = Word.fromMap(map);
        distractors.add(word);
        excludeIds.add(word.id!);
      }
    }

    // Step 3: If still not enough, get from other word lists (same language)
    if (distractors.length < count) {
      final needed = count - distractors.length;
      final otherListResults = await db.rawQuery('''
        SELECT * FROM ${DbConstants.tableWords}
        WHERE word_list_id != ? AND language = ? AND id NOT IN (${excludeIds.join(',')})
        ORDER BY RANDOM()
        LIMIT ?
      ''', [wordListId, language, needed]);

      for (final map in otherListResults) {
        final word = Word.fromMap(map);
        distractors.add(word);
        excludeIds.add(word.id!);
      }
    }

    return distractors;
  }

  /// Get reading distractors for kanji reading quiz.
  /// Prioritizes readings with similar length/pattern to the correct answer.
  Future<List<String>> getReadingDistractors({
    required String correctReading,
    required int wordListId,
    required int excludeWordId,
    int count = 3,
  }) async {
    final db = await _db;
    final distractors = <String>[];
    final usedReadings = <String>{correctReading.trim()};
    final correctLength = correctReading.length;

    // Get all kanji with readings from the same word list
    // Include words even if onyomi/kunyomi might not be populated
    final results = await db.rawQuery('''
      SELECT onyomi, kunyomi, reading FROM ${DbConstants.tableWords}
      WHERE word_list_id = ? AND id != ?
      ORDER BY RANDOM()
    ''', [wordListId, excludeWordId]);

    // Collect all unique readings with their length difference from correct
    final candidateReadings = <({String reading, int lengthDiff})>[];

    for (final row in results) {
      final onyomi = row['onyomi'] as String?;
      final kunyomi = row['kunyomi'] as String?;
      final wordReading = row['reading'] as String?;

      // Parse onyomi readings
      if (onyomi != null && onyomi.isNotEmpty) {
        for (final r in onyomi.split(RegExp(r'[、,]'))) {
          final reading = r.trim();
          if (reading.isNotEmpty && !usedReadings.contains(reading)) {
            usedReadings.add(reading);
            candidateReadings.add((
              reading: reading,
              lengthDiff: (reading.length - correctLength).abs(),
            ));
          }
        }
      }

      // Parse kunyomi readings
      if (kunyomi != null && kunyomi.isNotEmpty) {
        for (final r in kunyomi.split(RegExp(r'[、,]'))) {
          final reading = r.trim();
          if (reading.isNotEmpty && !usedReadings.contains(reading)) {
            usedReadings.add(reading);
            candidateReadings.add((
              reading: reading,
              lengthDiff: (reading.length - correctLength).abs(),
            ));
          }
        }
      }

      // Also use the word's reading field if available
      if (wordReading != null && wordReading.isNotEmpty && !usedReadings.contains(wordReading)) {
        usedReadings.add(wordReading);
        candidateReadings.add((
          reading: wordReading,
          lengthDiff: (wordReading.length - correctLength).abs(),
        ));
      }
    }

    // Sort by length similarity (smaller difference = more similar)
    candidateReadings.sort((a, b) => a.lengthDiff.compareTo(b.lengthDiff));

    // Take top candidates, but add some randomization among similar-length ones
    // Group by length difference and shuffle within each group
    final grouped = <int, List<String>>{};
    for (final c in candidateReadings) {
      grouped.putIfAbsent(c.lengthDiff, () => []).add(c.reading);
    }

    for (final diff in grouped.keys.toList()..sort()) {
      final group = grouped[diff]!..shuffle();
      for (final reading in group) {
        if (distractors.length >= count) break;
        distractors.add(reading);
      }
      if (distractors.length >= count) break;
    }

    return distractors;
  }

  /// Get kanji distractors for kanji selection quiz.
  /// Returns kanji from the same word list, prioritizing ones with similar patterns.
  Future<List<Word>> getKanjiDistractors({
    required int wordListId,
    required int excludeWordId,
    int count = 3,
  }) async {
    final db = await _db;
    final distractors = <Word>[];
    final excludeIds = <int>{excludeWordId};

    // Get any words from the same word list (for kanji lists, all should be kanji)
    // Don't filter by onyomi/kunyomi as they might not be populated in existing data
    final results = await db.rawQuery('''
      SELECT * FROM ${DbConstants.tableWords}
      WHERE word_list_id = ? AND id NOT IN (${excludeIds.join(',')})
      ORDER BY RANDOM()
      LIMIT ?
    ''', [wordListId, count]);

    for (final map in results) {
      final word = Word.fromMap(map);
      distractors.add(word);
      excludeIds.add(word.id!);
    }

    // If not enough, try other Japanese word lists
    if (distractors.length < count) {
      final needed = count - distractors.length;
      final otherResults = await db.rawQuery('''
        SELECT * FROM ${DbConstants.tableWords}
        WHERE word_list_id != ? AND language = 'ja'
          AND id NOT IN (${excludeIds.join(',')})
        ORDER BY RANDOM()
        LIMIT ?
      ''', [wordListId, needed]);

      for (final map in otherResults) {
        final word = Word.fromMap(map);
        distractors.add(word);
      }
    }

    return distractors;
  }

  /// Get kanji words that have examples (for kanji selection quiz)
  Future<List<Word>> getKanjiWithExamples(int wordListId, {int limit = 100}) async {
    final db = await _db;

    // Get kanji that have at least one example sentence
    final wordMaps = await db.rawQuery('''
      SELECT DISTINCT w.* FROM ${DbConstants.tableWords} w
      INNER JOIN ${DbConstants.tableExampleSentences} e ON w.id = e.word_id
      WHERE w.word_list_id = ?
        AND (w.onyomi IS NOT NULL OR w.kunyomi IS NOT NULL)
      LIMIT ?
    ''', [wordListId, limit]);

    final words = <Word>[];
    for (final map in wordMaps) {
      final word = Word.fromMap(map);
      final sentences = await _getExampleSentences(db, word.id!);
      words.add(word.copyWith(exampleSentences: sentences));
    }
    return words;
  }
}
