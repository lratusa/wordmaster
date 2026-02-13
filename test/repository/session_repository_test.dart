import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/study/data/repositories/session_repository.dart';

import 'test_database_helper.dart';

void main() {
  late Database db;
  late SessionRepository repo;
  late int wordListId;

  setUp(() async {
    db = await createTestDatabase();
    repo = SessionRepository();
    wordListId = await insertTestWordList(db, name: 'Session Test List');
  });

  tearDown(() async {
    await db.close();
  });

  group('SessionRepository', () {
    group('createSession', () {
      test('returns a positive session ID', () async {
        final id = await repo.createSession(
          sessionType: 'flashcard',
          wordListId: wordListId,
        );
        expect(id, greaterThan(0));
      });

      test('creates session with correct type', () async {
        final id = await repo.createSession(
          sessionType: 'audio',
          language: 'en',
          wordListId: wordListId,
        );
        final rows = await db.query('review_sessions', where: 'id = ?', whereArgs: [id]);
        expect(rows.first['session_type'], 'audio');
        expect(rows.first['language'], 'en');
      });

      test('sets session_date and started_at', () async {
        final id = await repo.createSession(sessionType: 'flashcard');
        final rows = await db.query('review_sessions', where: 'id = ?', whereArgs: [id]);
        expect(rows.first['session_date'], isNotNull);
        expect(rows.first['started_at'], isNotNull);
      });

      test('creates multiple independent sessions', () async {
        final id1 = await repo.createSession(sessionType: 'flashcard');
        final id2 = await repo.createSession(sessionType: 'flashcard');
        expect(id1, isNot(equals(id2)));
      });
    });

    group('completeSession', () {
      test('updates session with completion stats', () async {
        final id = await repo.createSession(sessionType: 'flashcard');
        await repo.completeSession(
          sessionId: id,
          totalWords: 20,
          newWords: 5,
          reviewWords: 15,
          correctCount: 18,
          incorrectCount: 2,
          starredCount: 3,
          durationSeconds: 300,
        );

        final rows = await db.query('review_sessions', where: 'id = ?', whereArgs: [id]);
        final row = rows.first;
        expect(row['total_words'], 20);
        expect(row['new_words'], 5);
        expect(row['review_words'], 15);
        expect(row['correct_count'], 18);
        expect(row['incorrect_count'], 2);
        expect(row['starred_count'], 3);
        expect(row['duration_seconds'], 300);
        expect(row['completed_at'], isNotNull);
      });
    });

    group('logReview', () {
      test('inserts a review log entry', () async {
        final sessionId = await repo.createSession(sessionType: 'flashcard');
        final wordId = await insertTestWord(
          db,
          wordListId: wordListId,
          word: 'test',
        );

        await repo.logReview(
          sessionId: sessionId,
          wordId: wordId,
          rating: 3,
          responseTimeMs: 1500,
        );

        final logs = await db.query('review_logs', where: 'session_id = ?', whereArgs: [sessionId]);
        expect(logs.length, 1);
        expect(logs.first['word_id'], wordId);
        expect(logs.first['rating'], 3);
        expect(logs.first['response_time_ms'], 1500);
      });

      test('can log multiple reviews per session', () async {
        final sessionId = await repo.createSession(sessionType: 'flashcard');
        final w1 = await insertTestWord(db, wordListId: wordListId, word: 'a');
        final w2 = await insertTestWord(db, wordListId: wordListId, word: 'b');

        await repo.logReview(sessionId: sessionId, wordId: w1, rating: 4);
        await repo.logReview(sessionId: sessionId, wordId: w2, rating: 1);

        final logs = await db.query('review_logs', where: 'session_id = ?', whereArgs: [sessionId]);
        expect(logs.length, 2);
      });

      test('stores FSRS review log JSON', () async {
        final sessionId = await repo.createSession(sessionType: 'flashcard');
        final wordId = await insertTestWord(db, wordListId: wordListId, word: 'c');

        await repo.logReview(
          sessionId: sessionId,
          wordId: wordId,
          rating: 2,
          fsrsReviewLogJson: '{"log":"data"}',
        );

        final logs = await db.query('review_logs', where: 'session_id = ?', whereArgs: [sessionId]);
        expect(logs.first['fsrs_review_log_json'], '{"log":"data"}');
      });
    });

    group('getDailyStats', () {
      test('returns empty list when no sessions', () async {
        final stats = await repo.getDailyStats(7);
        expect(stats, isEmpty);
      });

      test('returns stats for completed sessions', () async {
        final id = await repo.createSession(sessionType: 'flashcard');
        await repo.completeSession(
          sessionId: id,
          totalWords: 10,
          newWords: 3,
          reviewWords: 7,
          correctCount: 9,
          incorrectCount: 1,
          starredCount: 0,
          durationSeconds: 120,
        );

        final stats = await repo.getDailyStats(7);
        expect(stats.length, 1);
        expect(stats.first.newWords, 3);
        expect(stats.first.reviewWords, 7);
        expect(stats.first.correctCount, 9);
        expect(stats.first.totalSeconds, 120);
      });

      test('excludes incomplete sessions', () async {
        // Create but don't complete
        await repo.createSession(sessionType: 'flashcard');

        final stats = await repo.getDailyStats(7);
        expect(stats, isEmpty);
      });
    });

    group('getAllTimeStats', () {
      test('returns zeros when no sessions', () async {
        final stats = await repo.getAllTimeStats();
        expect(stats.totalSessions, 0);
        expect(stats.totalWords, 0);
        expect(stats.totalMinutes, 0);
        expect(stats.avgCorrectRate, 0);
      });

      test('aggregates across multiple sessions', () async {
        for (int i = 0; i < 3; i++) {
          final id = await repo.createSession(sessionType: 'flashcard');
          await repo.completeSession(
            sessionId: id,
            totalWords: 10,
            newWords: 2,
            reviewWords: 8,
            correctCount: 8,
            incorrectCount: 2,
            starredCount: 0,
            durationSeconds: 60,
          );
        }

        final stats = await repo.getAllTimeStats();
        expect(stats.totalSessions, 3);
        expect(stats.totalWords, 30);
        expect(stats.totalMinutes, 3);
        expect(stats.avgCorrectRate, closeTo(0.8, 0.01));
      });
    });

    group('getTodayStats', () {
      test('returns zeros when no sessions today', () async {
        final stats = await repo.getTodayStats();
        expect(stats.newWords, 0);
        expect(stats.reviewWords, 0);
        expect(stats.correctCount, 0);
        expect(stats.totalMinutes, 0);
      });

      test('returns stats from completed sessions', () async {
        final id = await repo.createSession(sessionType: 'flashcard');
        await repo.completeSession(
          sessionId: id,
          totalWords: 15,
          newWords: 5,
          reviewWords: 10,
          correctCount: 12,
          incorrectCount: 3,
          starredCount: 1,
          durationSeconds: 180,
        );

        final stats = await repo.getTodayStats();
        expect(stats.newWords, 5);
        expect(stats.reviewWords, 10);
        expect(stats.correctCount, 12);
        expect(stats.totalMinutes, 3);
      });
    });
  });
}
