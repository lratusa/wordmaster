import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/word_lists/data/repositories/word_list_repository.dart';
import 'package:wordmaster/src/features/word_lists/domain/enums/language.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word_list.dart';

import 'test_database_helper.dart';

void main() {
  late Database db;
  late WordListRepository repo;

  setUp(() async {
    db = await createTestDatabase();
    repo = WordListRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('WordListRepository', () {
    group('getAllWordLists', () {
      test('returns empty list when no word lists', () async {
        final lists = await repo.getAllWordLists();
        expect(lists, isEmpty);
      });

      test('returns all word lists', () async {
        await insertTestWordList(db, name: 'List A', language: 'en');
        await insertTestWordList(db, name: 'List B', language: 'ja');

        final lists = await repo.getAllWordLists();
        expect(lists.length, 2);
      });

      test('includes learned count and review due count', () async {
        final listId = await insertTestWordList(db, name: 'Progress List');
        final w1 = await insertTestWord(db, wordListId: listId, word: 'a');
        final w2 = await insertTestWord(db, wordListId: listId, word: 'b');

        // w1 is learned (is_new = 0), due for review (past due date)
        final pastDate = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
        await insertTestProgress(db, wordId: w1, isNew: 0, dueDate: pastDate);
        // w2 is still new
        await insertTestProgress(db, wordId: w2, isNew: 1);

        final lists = await repo.getAllWordLists();
        final list = lists.first;
        expect(list.learnedCount, 1);
        expect(list.reviewDueCount, 1);
      });
    });

    group('getWordListById', () {
      test('returns null for non-existent ID', () async {
        final list = await repo.getWordListById(9999);
        expect(list, isNull);
      });

      test('returns word list with progress info', () async {
        final id = await insertTestWordList(db, name: 'Find Me');
        final list = await repo.getWordListById(id);
        expect(list, isNotNull);
        expect(list!.name, 'Find Me');
      });
    });

    group('getWordListsByLanguage', () {
      test('filters by language', () async {
        await insertTestWordList(db, name: 'English List', language: 'en');
        await insertTestWordList(db, name: 'Japanese List', language: 'ja');

        final enLists = await repo.getWordListsByLanguage(Language.en);
        expect(enLists.length, 1);
        expect(enLists.first.name, 'English List');

        final jaLists = await repo.getWordListsByLanguage(Language.ja);
        expect(jaLists.length, 1);
        expect(jaLists.first.name, 'Japanese List');
      });
    });

    group('createWordList', () {
      test('creates word list and returns ID', () async {
        final wl = WordList(
          name: 'My Custom List',
          language: Language.en,
          type: WordListType.custom,
          description: 'A custom list',
        );
        final id = await repo.createWordList(wl);
        expect(id, greaterThan(0));

        final fetched = await repo.getWordListById(id);
        expect(fetched!.name, 'My Custom List');
        expect(fetched.type, WordListType.custom);
      });
    });

    group('deleteWordList', () {
      test('deletes word list', () async {
        final id = await insertTestWordList(db, name: 'Delete Me');
        await repo.deleteWordList(id);

        final fetched = await repo.getWordListById(id);
        expect(fetched, isNull);
      });

      test('cascade deletes words', () async {
        final listId = await insertTestWordList(db, name: 'Cascade Test');
        await insertTestWord(db, wordListId: listId, word: 'orphan');

        await repo.deleteWordList(listId);

        final words = await db.query('words', where: 'word_list_id = ?', whereArgs: [listId]);
        expect(words, isEmpty);
      });

      test('cascade deletes example sentences', () async {
        final listId = await insertTestWordList(db, name: 'Deep Cascade');
        final wordId = await insertTestWord(db, wordListId: listId, word: 'deep');
        await insertTestSentence(db, wordId: wordId, sentence: 'Deep sentence');

        await repo.deleteWordList(listId);

        final sentences = await db.query('example_sentences', where: 'word_id = ?', whereArgs: [wordId]);
        expect(sentences, isEmpty);
      });
    });

    group('importWordListWithWords', () {
      test('imports word list with words', () async {
        final wl = WordList(
          name: 'Imported List',
          language: Language.en,
          type: WordListType.builtIn,
          wordCount: 2,
        );
        final words = [
          Word(wordListId: 0, language: Language.en, word: 'import1', translationCn: '导入1'),
          Word(wordListId: 0, language: Language.en, word: 'import2', translationCn: '导入2'),
        ];

        final id = await repo.importWordListWithWords(wl, words);
        expect(id, greaterThan(0));

        final dbWords = await db.query('words', where: 'word_list_id = ?', whereArgs: [id]);
        expect(dbWords.length, 2);
      });

      test('skips duplicate by name', () async {
        final wl = WordList(name: 'Unique Name', language: Language.en);
        await repo.importWordListWithWords(wl, []);
        final id2 = await repo.importWordListWithWords(wl, []);

        // Should return existing ID, not create new
        final lists = await db.query('word_lists', where: "name = 'Unique Name'");
        expect(lists.length, 1);
        expect(id2, lists.first['id']);
      });
    });

    group('getWordListByName', () {
      test('returns null for non-existent name', () async {
        final list = await repo.getWordListByName('Nonexistent');
        expect(list, isNull);
      });

      test('finds word list by name', () async {
        await insertTestWordList(db, name: 'CEFR A2');
        final list = await repo.getWordListByName('CEFR A2');
        expect(list, isNotNull);
        expect(list!.name, 'CEFR A2');
      });
    });
  });
}
