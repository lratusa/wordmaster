import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/word_lists/data/repositories/word_repository.dart';
import 'package:wordmaster/src/features/word_lists/domain/enums/language.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word.dart';

import 'test_database_helper.dart';

void main() {
  late Database db;
  late WordRepository repo;
  late int wordListId;

  setUp(() async {
    db = await createTestDatabase();
    repo = WordRepository();
    wordListId = await insertTestWordList(db, name: 'Word Repo Test');
  });

  tearDown(() async {
    await db.close();
  });

  group('WordRepository', () {
    group('getWordsByListId', () {
      test('returns empty list for empty word list', () async {
        final words = await repo.getWordsByListId(wordListId);
        expect(words, isEmpty);
      });

      test('returns all words in a list', () async {
        await insertTestWord(db, wordListId: wordListId, word: 'apple');
        await insertTestWord(db, wordListId: wordListId, word: 'banana');
        await insertTestWord(db, wordListId: wordListId, word: 'cherry');

        final words = await repo.getWordsByListId(wordListId);
        expect(words.length, 3);
        expect(words.map((w) => w.word), containsAll(['apple', 'banana', 'cherry']));
      });

      test('includes example sentences', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'hello');
        await insertTestSentence(db, wordId: wordId, sentence: 'Hello world!');
        await insertTestSentence(db, wordId: wordId, sentence: 'Say hello.', sortOrder: 1);

        final words = await repo.getWordsByListId(wordListId);
        expect(words.first.exampleSentences.length, 2);
      });
    });

    group('getWordById', () {
      test('returns null for non-existent ID', () async {
        final word = await repo.getWordById(9999);
        expect(word, isNull);
      });

      test('returns word with example sentences', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'test');
        await insertTestSentence(db, wordId: wordId, sentence: 'This is a test.');

        final word = await repo.getWordById(wordId);
        expect(word, isNotNull);
        expect(word!.word, 'test');
        expect(word.exampleSentences.length, 1);
      });
    });

    group('searchWords', () {
      test('returns empty for blank query', () async {
        await insertTestWord(db, wordListId: wordListId, word: 'test');
        final results = await repo.searchWords('');
        expect(results, isEmpty);
      });

      test('finds words by English text', () async {
        await insertTestWord(db, wordListId: wordListId, word: 'beautiful');
        await insertTestWord(db, wordListId: wordListId, word: 'beauty');
        await insertTestWord(db, wordListId: wordListId, word: 'ugly');

        final results = await repo.searchWords('beaut');
        expect(results.length, 2);
      });

      test('finds words by Chinese translation', () async {
        await insertTestWord(db, wordListId: wordListId, word: 'apple', translationCn: '苹果');
        await insertTestWord(db, wordListId: wordListId, word: 'banana', translationCn: '香蕉');

        final results = await repo.searchWords('苹果');
        expect(results.length, 1);
        expect(results.first.word, 'apple');
      });

      test('finds words by reading', () async {
        await insertTestWord(
          db,
          wordListId: wordListId,
          word: '山',
          language: 'ja',
          reading: 'やま',
        );
        final results = await repo.searchWords('やま');
        expect(results.length, 1);
      });
    });

    group('insertWord', () {
      test('inserts word and returns ID', () async {
        final word = Word(
          wordListId: wordListId,
          language: Language.en,
          word: 'new_word',
          translationCn: '新词',
          partOfSpeech: 'n.',
        );
        final id = await repo.insertWord(word);
        expect(id, greaterThan(0));

        final fetched = await repo.getWordById(id);
        expect(fetched!.word, 'new_word');
        expect(fetched.partOfSpeech, 'n.');
      });

      test('inserts word with example sentences', () async {
        final word = Word(
          wordListId: wordListId,
          language: Language.en,
          word: 'example',
          translationCn: '例子',
          exampleSentences: [
            ExampleSentence(wordId: 0, sentence: 'For example...', translationCn: '例如...'),
          ],
        );
        final id = await repo.insertWord(word);
        final fetched = await repo.getWordById(id);
        expect(fetched!.exampleSentences.length, 1);
        expect(fetched.exampleSentences.first.sentence, 'For example...');
      });

      test('updates word count in word list', () async {
        final word = Word(
          wordListId: wordListId,
          language: Language.en,
          word: 'counted',
          translationCn: '被计数的',
        );
        await repo.insertWord(word);

        final wlRows = await db.query('word_lists', where: 'id = ?', whereArgs: [wordListId]);
        expect(wlRows.first['word_count'], 1);
      });
    });

    group('deleteWord', () {
      test('deletes word and updates count', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'delete_me');
        // Update count manually to simulate normal state
        await db.update('word_lists', {'word_count': 1}, where: 'id = ?', whereArgs: [wordListId]);

        await repo.deleteWord(wordId);

        final word = await repo.getWordById(wordId);
        expect(word, isNull);
      });

      test('does nothing for non-existent ID', () async {
        await repo.deleteWord(9999);
        // No exception means pass
      });
    });

    group('getDistractors', () {
      test('returns distractors from same word list', () async {
        final target = await insertTestWord(db, wordListId: wordListId, word: 'target', partOfSpeech: 'n.');
        await insertTestWord(db, wordListId: wordListId, word: 'd1', partOfSpeech: 'n.');
        await insertTestWord(db, wordListId: wordListId, word: 'd2', partOfSpeech: 'n.');
        await insertTestWord(db, wordListId: wordListId, word: 'd3', partOfSpeech: 'v.');

        final distractors = await repo.getDistractors(
          wordListId: wordListId,
          excludeWordId: target,
          language: 'en',
          preferPartOfSpeech: 'n.',
          count: 3,
        );

        expect(distractors.length, 3);
        expect(distractors.every((d) => d.id != target), true);
      });

      test('falls back to other word lists if not enough', () async {
        final otherList = await insertTestWordList(db, name: 'Other List');
        await insertTestWord(db, wordListId: otherList, word: 'other1');
        await insertTestWord(db, wordListId: otherList, word: 'other2');
        await insertTestWord(db, wordListId: otherList, word: 'other3');

        final target = await insertTestWord(db, wordListId: wordListId, word: 'lonely');

        final distractors = await repo.getDistractors(
          wordListId: wordListId,
          excludeWordId: target,
          language: 'en',
          count: 3,
        );

        expect(distractors.length, 3);
      });
    });

    group('getWordCount', () {
      test('returns 0 for empty list', () async {
        final count = await repo.getWordCount(wordListId);
        expect(count, 0);
      });

      test('returns correct count', () async {
        await insertTestWord(db, wordListId: wordListId, word: 'a');
        await insertTestWord(db, wordListId: wordListId, word: 'b');
        final count = await repo.getWordCount(wordListId);
        expect(count, 2);
      });
    });
  });
}
