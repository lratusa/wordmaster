import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/study/data/repositories/progress_repository.dart';

import 'test_database_helper.dart';

void main() {
  late Database db;
  late ProgressRepository repo;
  late int wordListId;

  setUp(() async {
    db = await createTestDatabase();
    repo = ProgressRepository();
    wordListId = await insertTestWordList(db, name: 'Test Words');
  });

  tearDown(() async {
    await db.close();
  });

  group('ProgressRepository', () {
    group('getOrCreateProgress', () {
      test('creates new progress for unknown word', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'apple');
        final progress = await repo.getOrCreateProgress(wordId);

        expect(progress.id, isNotNull);
        expect(progress.wordId, wordId);
        expect(progress.isNew, true);
        expect(progress.isStarred, false);
        expect(progress.reviewCount, 0);
        expect(progress.correctCount, 0);
      });

      test('returns existing progress on second call', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'banana');
        final first = await repo.getOrCreateProgress(wordId);
        final second = await repo.getOrCreateProgress(wordId);

        expect(second.id, first.id);
        expect(second.wordId, first.wordId);
      });

      test('creates FSRS card JSON', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'cat');
        final progress = await repo.getOrCreateProgress(wordId);

        expect(progress.fsrsCardJson, isNotEmpty);
        expect(progress.fsrsCardJson, isNot('{}'));
      });
    });

    group('updateProgress', () {
      test('updates progress fields', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'dog');
        final progress = await repo.getOrCreateProgress(wordId);

        final updated = progress.copyWith(
          reviewCount: 5,
          correctCount: 4,
          isNew: false,
        );
        await repo.updateProgress(updated);

        final fetched = await repo.getOrCreateProgress(wordId);
        expect(fetched.reviewCount, 5);
        expect(fetched.correctCount, 4);
        expect(fetched.isNew, false);
      });
    });

    group('getDueWordIds', () {
      test('returns empty list when no due words', () async {
        final ids = await repo.getDueWordIds(wordListId);
        expect(ids, isEmpty);
      });

      test('returns words with past due date and not new', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'due');
        final pastDate = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
        await insertTestProgress(db, wordId: wordId, dueDate: pastDate, isNew: 0);

        final ids = await repo.getDueWordIds(wordListId);
        expect(ids, contains(wordId));
      });

      test('excludes new words', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'new');
        final pastDate = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
        await insertTestProgress(db, wordId: wordId, dueDate: pastDate, isNew: 1);

        final ids = await repo.getDueWordIds(wordListId);
        expect(ids, isEmpty);
      });

      test('excludes words with future due date', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'future');
        final futureDate = DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String();
        await insertTestProgress(db, wordId: wordId, dueDate: futureDate, isNew: 0);

        final ids = await repo.getDueWordIds(wordListId);
        expect(ids, isEmpty);
      });
    });

    group('getNewWordIds', () {
      test('returns words without progress', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'fresh');
        final ids = await repo.getNewWordIds(wordListId);
        expect(ids, contains(wordId));
      });

      test('returns words with is_new = 1', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'new2');
        await insertTestProgress(db, wordId: wordId, isNew: 1);

        final ids = await repo.getNewWordIds(wordListId);
        expect(ids, contains(wordId));
      });

      test('excludes learned words', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'learned');
        await insertTestProgress(db, wordId: wordId, isNew: 0);

        final ids = await repo.getNewWordIds(wordListId);
        expect(ids, isEmpty);
      });

      test('respects limit parameter', () async {
        for (int i = 0; i < 5; i++) {
          await insertTestWord(db, wordListId: wordListId, word: 'word$i');
        }
        final ids = await repo.getNewWordIds(wordListId, limit: 3);
        expect(ids.length, 3);
      });
    });

    group('toggleStar', () {
      test('stars an unstarred word', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'star');
        await repo.getOrCreateProgress(wordId); // ensure progress exists

        await repo.toggleStar(wordId);
        final progress = await repo.getOrCreateProgress(wordId);
        expect(progress.isStarred, true);
      });

      test('unstars a starred word', () async {
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'unstar');
        await repo.getOrCreateProgress(wordId);

        await repo.toggleStar(wordId); // star
        await repo.toggleStar(wordId); // unstar
        final progress = await repo.getOrCreateProgress(wordId);
        expect(progress.isStarred, false);
      });
    });

    group('getStarredWordIds', () {
      test('returns only starred word IDs', () async {
        final w1 = await insertTestWord(db, wordListId: wordListId, word: 'a');
        final w2 = await insertTestWord(db, wordListId: wordListId, word: 'b');
        await repo.getOrCreateProgress(w1);
        await repo.getOrCreateProgress(w2);
        await repo.toggleStar(w1);

        final starred = await repo.getStarredWordIds();
        expect(starred, contains(w1));
        expect(starred, isNot(contains(w2)));
      });
    });

    group('getTotalLearnedCount', () {
      test('returns 0 when no learned words', () async {
        final count = await repo.getTotalLearnedCount();
        expect(count, 0);
      });

      test('counts only non-new words', () async {
        final w1 = await insertTestWord(db, wordListId: wordListId, word: 'x');
        final w2 = await insertTestWord(db, wordListId: wordListId, word: 'y');
        await insertTestProgress(db, wordId: w1, isNew: 0);
        await insertTestProgress(db, wordId: w2, isNew: 1);

        final count = await repo.getTotalLearnedCount();
        expect(count, 1);
      });
    });
  });
}
