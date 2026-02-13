import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/checkin/data/repositories/checkin_repository.dart';

import '../repository/test_database_helper.dart';

void main() {
  late Database db;
  late CheckinRepository checkinRepo;

  setUp(() async {
    db = await createTestDatabase();
    checkinRepo = CheckinRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkin Flow Integration', () {
    test('first checkin creates streak of 1', () async {
      final record = await checkinRepo.checkin(
        newWords: 10,
        reviewWords: 20,
        correctRate: 0.9,
        studyMinutes: 30,
      );

      expect(record.streakDays, 1);
      expect(await checkinRepo.hasCheckedInToday(), true);
      expect(await checkinRepo.getStreakDays(), 1);
    });

    test('consecutive checkins build streak', () async {
      // Simulate 3-day streak by inserting past checkins
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

      await db.insert('daily_checkins', {
        'checkin_date': twoDaysAgo.toIso8601String().substring(0, 10),
        'new_words': 5, 'review_words': 10, 'correct_rate': 0.8,
        'study_minutes': 10, 'streak_days': 1,
      });
      await db.insert('daily_checkins', {
        'checkin_date': yesterday.toIso8601String().substring(0, 10),
        'new_words': 8, 'review_words': 15, 'correct_rate': 0.85,
        'study_minutes': 20, 'streak_days': 2,
      });

      final record = await checkinRepo.checkin(
        newWords: 10,
        reviewWords: 20,
        correctRate: 0.9,
        studyMinutes: 25,
      );

      expect(record.streakDays, 3);
      expect(record.achievements, contains('streak_3'));
    });

    test('streak resets after gap', () async {
      // Insert checkin 3 days ago (gap > 1 day)
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      await db.insert('daily_checkins', {
        'checkin_date': threeDaysAgo.toIso8601String().substring(0, 10),
        'new_words': 5, 'review_words': 10, 'correct_rate': 0.8,
        'study_minutes': 10, 'streak_days': 5,
      });

      final record = await checkinRepo.checkin(
        newWords: 5,
        reviewWords: 10,
        correctRate: 0.8,
        studyMinutes: 10,
      );

      // Streak should reset to 1 (gap breaks the streak)
      expect(record.streakDays, 1);
    });

    test('checkin history returns records in date order', () async {
      // Insert past checkins
      for (int i = 3; i >= 1; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        await db.insert('daily_checkins', {
          'checkin_date': date.toIso8601String().substring(0, 10),
          'new_words': i * 5, 'review_words': i * 10, 'correct_rate': 0.8,
          'study_minutes': i * 10, 'streak_days': 4 - i,
        });
      }

      final history = await checkinRepo.getCheckinHistory(7);
      expect(history.length, 3);
      // Should be in ascending date order
      for (int i = 0; i < history.length - 1; i++) {
        expect(
          history[i].checkinDate.compareTo(history[i + 1].checkinDate),
          lessThanOrEqualTo(0),
        );
      }
    });

    test('total study days counts all checkin entries', () async {
      // Insert 3 past checkins
      for (int i = 1; i <= 3; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        await db.insert('daily_checkins', {
          'checkin_date': date.toIso8601String().substring(0, 10),
          'new_words': 5, 'review_words': 10, 'correct_rate': 0.8,
          'study_minutes': 10, 'streak_days': i,
        });
      }

      final totalDays = await checkinRepo.getTotalStudyDays();
      expect(totalDays, 3);

      // Add today's checkin
      await checkinRepo.checkin(
        newWords: 5, reviewWords: 10, correctRate: 0.9, studyMinutes: 15,
      );
      final updatedDays = await checkinRepo.getTotalStudyDays();
      expect(updatedDays, 4);
    });

    test('achievements persist and are queryable', () async {
      // Initial state: all locked
      var achievements = await checkinRepo.getAchievements();
      expect(achievements.every((a) => !a.isUnlocked), true);

      // After 7-day streak, streak_3 and streak_7 should unlock
      for (int i = 6; i >= 1; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        await db.insert('daily_checkins', {
          'checkin_date': date.toIso8601String().substring(0, 10),
          'new_words': 5, 'review_words': 10, 'correct_rate': 0.8,
          'study_minutes': 10, 'streak_days': 7 - i,
        });
      }

      await checkinRepo.checkin(
        newWords: 5, reviewWords: 10, correctRate: 0.8, studyMinutes: 10,
      );

      achievements = await checkinRepo.getAchievements();
      final streak3 = achievements.firstWhere((a) => a.key == 'streak_3');
      final streak7 = achievements.firstWhere((a) => a.key == 'streak_7');
      expect(streak3.isUnlocked, true);
      expect(streak7.isUnlocked, true);
    });
  });
}
