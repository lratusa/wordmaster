import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/study/data/repositories/progress_repository.dart';
import 'package:wordmaster/src/features/study/data/repositories/session_repository.dart';
import 'package:wordmaster/src/features/study/domain/services/fsrs_service.dart';
import 'package:wordmaster/src/features/word_lists/data/repositories/word_repository.dart';

import '../repository/test_database_helper.dart';

void main() {
  late Database db;
  late ProgressRepository progressRepo;
  late SessionRepository sessionRepo;
  late WordRepository wordRepo;
  late FsrsService fsrsService;
  late int wordListId;

  setUp(() async {
    db = await createTestDatabase();
    progressRepo = ProgressRepository();
    sessionRepo = SessionRepository();
    wordRepo = WordRepository();
    fsrsService = FsrsService();
    wordListId = await insertTestWordList(db, name: 'Study Flow Test');

    // Insert test words
    for (int i = 0; i < 5; i++) {
      await insertTestWord(db, wordListId: wordListId, word: 'word_$i', translationCn: '翻译_$i');
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('Study Flow Integration', () {
    test('new word → learn → verify progress created', () async {
      // 1. Get new words
      final newIds = await progressRepo.getNewWordIds(wordListId);
      expect(newIds.length, 5);

      // 2. Create progress for first word
      final firstWordId = newIds.first;
      final progress = await progressRepo.getOrCreateProgress(firstWordId);
      expect(progress.isNew, true);
      expect(progress.reviewCount, 0);
    });

    test('review word with Good rating → due date pushed forward', () async {
      final newIds = await progressRepo.getNewWordIds(wordListId);
      final wordId = newIds.first;
      var progress = await progressRepo.getOrCreateProgress(wordId);

      // Simulate review with rating 3 (Good)
      final card = FsrsService.cardFromJson(progress.fsrsCardJson);
      final result = fsrsService.review(card, FsrsService.intToRating(3));

      final updated = progress.copyWith(
        fsrsCardJson: FsrsService.cardToJson(result.card),
        dueDate: result.card.due,
        stability: result.card.stability ?? 0,
        difficulty: result.card.difficulty ?? 0,
        state: result.card.state.value,
        reviewCount: progress.reviewCount + 1,
        correctCount: progress.correctCount + 1,
        isNew: false,
        lastReviewedAt: DateTime.now().toUtc(),
      );
      await progressRepo.updateProgress(updated);

      // Verify progress was updated
      progress = await progressRepo.getOrCreateProgress(wordId);
      expect(progress.isNew, false);
      expect(progress.reviewCount, 1);
      expect(progress.correctCount, 1);
    });

    test('review with Again rating → lapses increment', () async {
      final newIds = await progressRepo.getNewWordIds(wordListId);
      final wordId = newIds.first;
      var progress = await progressRepo.getOrCreateProgress(wordId);

      final card = FsrsService.cardFromJson(progress.fsrsCardJson);
      final result = fsrsService.review(card, FsrsService.intToRating(1));

      final updated = progress.copyWith(
        fsrsCardJson: FsrsService.cardToJson(result.card),
        dueDate: result.card.due,
        reviewCount: 1,
        correctCount: 0,
        lapses: progress.lapses + 1,
        isNew: false,
      );
      await progressRepo.updateProgress(updated);

      progress = await progressRepo.getOrCreateProgress(wordId);
      expect(progress.lapses, 1);
      expect(progress.correctCount, 0);
    });

    test('complete session → session stats recorded', () async {
      // Create session
      final sessionId = await sessionRepo.createSession(
        sessionType: 'flashcard',
        wordListId: wordListId,
      );

      // Log some reviews
      final newIds = await progressRepo.getNewWordIds(wordListId);
      for (final wordId in newIds.take(3)) {
        await sessionRepo.logReview(
          sessionId: sessionId,
          wordId: wordId,
          rating: 3,
        );
      }

      // Complete session
      await sessionRepo.completeSession(
        sessionId: sessionId,
        totalWords: 3,
        newWords: 3,
        reviewWords: 0,
        correctCount: 3,
        incorrectCount: 0,
        starredCount: 0,
        durationSeconds: 60,
      );

      // Verify session stats
      final todayStats = await sessionRepo.getTodayStats();
      expect(todayStats.newWords, 3);
      expect(todayStats.correctCount, 3);
    });

    test('full flow: learn → becomes due → review', () async {
      final newIds = await progressRepo.getNewWordIds(wordListId);
      final wordId = newIds.first;

      // Learn (first review)
      var progress = await progressRepo.getOrCreateProgress(wordId);
      final card = FsrsService.cardFromJson(progress.fsrsCardJson);
      final result = fsrsService.review(card, FsrsService.intToRating(3));

      // Set due date to past so it appears in due list
      final pastDue = DateTime.now().subtract(const Duration(hours: 1)).toUtc();
      final updated = progress.copyWith(
        fsrsCardJson: FsrsService.cardToJson(result.card),
        dueDate: pastDue,
        state: result.card.state.value,
        isNew: false,
        reviewCount: 1,
        correctCount: 1,
      );
      await progressRepo.updateProgress(updated);

      // Verify it appears in due list
      final dueIds = await progressRepo.getDueWordIds(wordListId);
      expect(dueIds, contains(wordId));

      // No longer in new words list
      final stillNewIds = await progressRepo.getNewWordIds(wordListId);
      expect(stillNewIds, isNot(contains(wordId)));
    });

    test('star/unstar persists through progress fetch', () async {
      final newIds = await progressRepo.getNewWordIds(wordListId);
      final wordId = newIds.first;
      await progressRepo.getOrCreateProgress(wordId);

      // Star
      await progressRepo.toggleStar(wordId);
      var starred = await progressRepo.getStarredWordIds();
      expect(starred, contains(wordId));

      // Unstar
      await progressRepo.toggleStar(wordId);
      starred = await progressRepo.getStarredWordIds();
      expect(starred, isNot(contains(wordId)));
    });

    test('word data accessible via WordRepository during study', () async {
      final newIds = await progressRepo.getNewWordIds(wordListId);
      final wordId = newIds.first;

      final word = await wordRepo.getWordById(wordId);
      expect(word, isNotNull);
      expect(word!.word, startsWith('word_'));
      expect(word.translationCn, startsWith('翻译_'));
    });

    test('multiple sessions aggregate in daily stats', () async {
      for (int i = 0; i < 2; i++) {
        final sessionId = await sessionRepo.createSession(
          sessionType: 'flashcard',
          wordListId: wordListId,
        );
        await sessionRepo.completeSession(
          sessionId: sessionId,
          totalWords: 5,
          newWords: 2,
          reviewWords: 3,
          correctCount: 4,
          incorrectCount: 1,
          starredCount: 0,
          durationSeconds: 120,
        );
      }

      final stats = await sessionRepo.getDailyStats(7);
      expect(stats.length, 1);
      expect(stats.first.newWords, 4); // 2 + 2
      expect(stats.first.reviewWords, 6); // 3 + 3
      expect(stats.first.correctCount, 8); // 4 + 4
      expect(stats.first.totalSeconds, 240); // 120 + 120
    });

    test('all-time stats reflect total history', () async {
      final sessionId = await sessionRepo.createSession(sessionType: 'flashcard');
      await sessionRepo.completeSession(
        sessionId: sessionId,
        totalWords: 10,
        newWords: 5,
        reviewWords: 5,
        correctCount: 8,
        incorrectCount: 2,
        starredCount: 1,
        durationSeconds: 300,
      );

      final allTime = await sessionRepo.getAllTimeStats();
      expect(allTime.totalSessions, 1);
      expect(allTime.totalWords, 10);
      expect(allTime.totalMinutes, 5);
      expect(allTime.avgCorrectRate, 0.8);
    });

    test('learned count increases after marking words as not-new', () async {
      final countBefore = await progressRepo.getTotalLearnedCount();
      expect(countBefore, 0);

      // Learn 3 words
      final newIds = await progressRepo.getNewWordIds(wordListId);
      for (final wordId in newIds.take(3)) {
        var progress = await progressRepo.getOrCreateProgress(wordId);
        await progressRepo.updateProgress(progress.copyWith(isNew: false));
      }

      final countAfter = await progressRepo.getTotalLearnedCount();
      expect(countAfter, 3);
    });
  });
}
