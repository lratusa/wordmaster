import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/checkin/data/repositories/checkin_repository.dart';

import 'test_database_helper.dart';

void main() {
  late Database db;
  late CheckinRepository repo;

  setUp(() async {
    db = await createTestDatabase();
    repo = CheckinRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('CheckinRepository', () {
    group('hasCheckedInToday', () {
      test('returns false when no checkins', () async {
        final result = await repo.hasCheckedInToday();
        expect(result, false);
      });

      test('returns true after checking in today', () async {
        await repo.checkin(
          newWords: 5,
          reviewWords: 10,
          correctRate: 0.8,
          studyMinutes: 15,
        );
        final result = await repo.hasCheckedInToday();
        expect(result, true);
      });
    });

    group('getStreakDays', () {
      test('returns 0 when no checkins', () async {
        final streak = await repo.getStreakDays();
        expect(streak, 0);
      });

      test('returns 1 after single checkin today', () async {
        await repo.checkin(
          newWords: 5,
          reviewWords: 10,
          correctRate: 0.9,
          studyMinutes: 10,
        );
        final streak = await repo.getStreakDays();
        expect(streak, 1);
      });

      test('counts consecutive days', () async {
        // Insert checkins for yesterday and day before manually
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final dayBefore = today.subtract(const Duration(days: 2));

        await db.insert('daily_checkins', {
          'checkin_date': dayBefore.toIso8601String().substring(0, 10),
          'new_words': 5,
          'review_words': 10,
          'correct_rate': 0.8,
          'study_minutes': 10,
          'streak_days': 1,
        });
        await db.insert('daily_checkins', {
          'checkin_date': yesterday.toIso8601String().substring(0, 10),
          'new_words': 5,
          'review_words': 10,
          'correct_rate': 0.8,
          'study_minutes': 10,
          'streak_days': 2,
        });

        final streak = await repo.getStreakDays();
        expect(streak, 2);
      });

      test('streak breaks with gap', () async {
        // Insert checkin 3 days ago (gap of 1 day)
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        await db.insert('daily_checkins', {
          'checkin_date': threeDaysAgo.toIso8601String().substring(0, 10),
          'new_words': 5,
          'review_words': 10,
          'correct_rate': 0.8,
          'study_minutes': 10,
          'streak_days': 1,
        });

        final streak = await repo.getStreakDays();
        expect(streak, 0);
      });
    });

    group('checkin', () {
      test('creates checkin record with correct data', () async {
        final record = await repo.checkin(
          newWords: 10,
          reviewWords: 20,
          correctRate: 0.85,
          studyMinutes: 25,
        );

        expect(record.newWords, 10);
        expect(record.reviewWords, 20);
        expect(record.correctRate, 0.85);
        expect(record.studyMinutes, 25);
        expect(record.streakDays, 1);
        expect(record.checkinDate, DateTime.now().toIso8601String().substring(0, 10));
      });

      test('increments streak from previous days', () async {
        // Insert yesterday's checkin
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await db.insert('daily_checkins', {
          'checkin_date': yesterday.toIso8601String().substring(0, 10),
          'new_words': 5,
          'review_words': 10,
          'correct_rate': 0.8,
          'study_minutes': 10,
          'streak_days': 1,
        });

        final record = await repo.checkin(
          newWords: 5,
          reviewWords: 10,
          correctRate: 0.9,
          studyMinutes: 15,
        );

        expect(record.streakDays, 2);
      });
    });

    group('getTodayCheckin', () {
      test('returns null when no checkin today', () async {
        final record = await repo.getTodayCheckin();
        expect(record, isNull);
      });

      test('returns today checkin after checking in', () async {
        await repo.checkin(
          newWords: 8,
          reviewWords: 12,
          correctRate: 0.75,
          studyMinutes: 20,
        );

        final record = await repo.getTodayCheckin();
        expect(record, isNotNull);
        expect(record!.newWords, 8);
        expect(record.reviewWords, 12);
        expect(record.correctRate, 0.75);
      });
    });

    group('getAchievements', () {
      test('returns all default achievements', () async {
        final achievements = await repo.getAchievements();
        expect(achievements.length, 10);
        expect(achievements.any((a) => a.key == 'first_checkin'), true);
        expect(achievements.any((a) => a.key == 'streak_7'), true);
        expect(achievements.any((a) => a.key == 'words_100'), true);
      });

      test('all achievements are initially locked', () async {
        final achievements = await repo.getAchievements();
        for (final a in achievements) {
          expect(a.isUnlocked, false);
        }
      });

      test('achievement unlocked after checkin with matching streak', () async {
        // streak_3 requires 3 consecutive days
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        await db.insert('daily_checkins', {
          'checkin_date': twoDaysAgo.toIso8601String().substring(0, 10),
          'new_words': 5, 'review_words': 5, 'correct_rate': 0.8, 'study_minutes': 5, 'streak_days': 1,
        });
        await db.insert('daily_checkins', {
          'checkin_date': yesterday.toIso8601String().substring(0, 10),
          'new_words': 5, 'review_words': 5, 'correct_rate': 0.8, 'study_minutes': 5, 'streak_days': 2,
        });

        // Third day checkin should unlock streak_3
        final record = await repo.checkin(
          newWords: 5, reviewWords: 5, correctRate: 0.8, studyMinutes: 5,
        );

        expect(record.streakDays, 3);
        expect(record.achievements, contains('streak_3'));
      });
    });

    group('getCheckinHistory', () {
      test('returns empty list when no checkins', () async {
        final history = await repo.getCheckinHistory(30);
        expect(history, isEmpty);
      });

      test('returns checkins within date range', () async {
        await repo.checkin(
          newWords: 5, reviewWords: 10, correctRate: 0.8, studyMinutes: 10,
        );

        final history = await repo.getCheckinHistory(30);
        expect(history.length, 1);
        expect(history.first.newWords, 5);
      });
    });

    group('getTotalWordsLearned', () {
      test('returns 0 when no progress', () async {
        final count = await repo.getTotalWordsLearned();
        expect(count, 0);
      });

      test('counts non-new words', () async {
        final listId = await insertTestWordList(db, name: 'Learn Test');
        final w1 = await insertTestWord(db, wordListId: listId, word: 'a');
        final w2 = await insertTestWord(db, wordListId: listId, word: 'b');
        await insertTestProgress(db, wordId: w1, isNew: 0);
        await insertTestProgress(db, wordId: w2, isNew: 1);

        final count = await repo.getTotalWordsLearned();
        expect(count, 1);
      });
    });

    group('getTotalStudyDays', () {
      test('returns 0 when no checkins', () async {
        final count = await repo.getTotalStudyDays();
        expect(count, 0);
      });

      test('counts checkin days', () async {
        await repo.checkin(
          newWords: 5, reviewWords: 10, correctRate: 0.8, studyMinutes: 10,
        );
        final count = await repo.getTotalStudyDays();
        expect(count, 1);
      });
    });
  });
}
