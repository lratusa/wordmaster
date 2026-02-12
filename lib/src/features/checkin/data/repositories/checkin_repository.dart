import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';

class CheckinRecord {
  final int? id;
  final String checkinDate;
  final int newWords;
  final int reviewWords;
  final double correctRate;
  final int studyMinutes;
  final int streakDays;
  final List<String> achievements;

  const CheckinRecord({
    this.id,
    required this.checkinDate,
    required this.newWords,
    required this.reviewWords,
    required this.correctRate,
    required this.studyMinutes,
    required this.streakDays,
    this.achievements = const [],
  });
}

class Achievement {
  final String key;
  final String name;
  final String description;
  final String iconName;
  final DateTime? unlockedAt;
  final int progress;
  final int target;

  const Achievement({
    required this.key,
    required this.name,
    required this.description,
    required this.iconName,
    this.unlockedAt,
    this.progress = 0,
    required this.target,
  });

  bool get isUnlocked => unlockedAt != null;
}

class CheckinRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Check if user has already checked in today
  Future<bool> hasCheckedInToday() async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.query(
      DbConstants.tableDailyCheckins,
      where: 'checkin_date = ?',
      whereArgs: [today],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Get the current streak count
  Future<int> getStreakDays() async {
    final db = await _db;
    final results = await db.query(
      DbConstants.tableDailyCheckins,
      orderBy: 'checkin_date DESC',
      limit: 365,
    );

    if (results.isEmpty) return 0;

    int streak = 0;
    var expectedDate = DateTime.now();

    for (final row in results) {
      final checkinDate = DateTime.parse(row['checkin_date'] as String);
      final diff = expectedDate.difference(checkinDate).inDays;

      if (diff <= 1) {
        streak++;
        expectedDate = checkinDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// Create a check-in record
  Future<CheckinRecord> checkin({
    required int newWords,
    required int reviewWords,
    required double correctRate,
    required int studyMinutes,
  }) async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Calculate streak
    final previousStreak = await getStreakDays();
    final streakDays = previousStreak + 1;

    // Check achievements
    final newAchievements = await _checkAchievements(
      streakDays: streakDays,
      newWords: newWords,
    );

    final record = CheckinRecord(
      checkinDate: today,
      newWords: newWords,
      reviewWords: reviewWords,
      correctRate: correctRate,
      studyMinutes: studyMinutes,
      streakDays: streakDays,
      achievements: newAchievements,
    );

    await db.insert(DbConstants.tableDailyCheckins, {
      'checkin_date': today,
      'new_words': newWords,
      'review_words': reviewWords,
      'correct_rate': correctRate,
      'study_minutes': studyMinutes,
      'streak_days': streakDays,
      'achievements':
          newAchievements.isNotEmpty ? jsonEncode(newAchievements) : null,
    });

    return record;
  }

  /// Get today's check-in record
  Future<CheckinRecord?> getTodayCheckin() async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.query(
      DbConstants.tableDailyCheckins,
      where: 'checkin_date = ?',
      whereArgs: [today],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return CheckinRecord(
      id: row['id'] as int,
      checkinDate: row['checkin_date'] as String,
      newWords: row['new_words'] as int,
      reviewWords: row['review_words'] as int,
      correctRate: (row['correct_rate'] as num).toDouble(),
      studyMinutes: row['study_minutes'] as int,
      streakDays: row['streak_days'] as int,
      achievements: row['achievements'] != null
          ? (jsonDecode(row['achievements'] as String) as List<dynamic>)
              .cast<String>()
          : [],
    );
  }

  /// Get all unlocked achievements
  Future<List<Achievement>> getAchievements() async {
    final db = await _db;
    final results = await db.query(DbConstants.tableAchievements);

    return results.map((row) {
      return Achievement(
        key: row['achievement_key'] as String,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        iconName: row['icon_name'] as String,
        unlockedAt: row['unlocked_at'] != null
            ? DateTime.tryParse(row['unlocked_at'] as String)
            : null,
        progress: row['progress'] as int? ?? 0,
        target: row['target'] as int,
      );
    }).toList();
  }

  /// Get check-in history for the last [days] days (for calendar/statistics)
  Future<List<CheckinRecord>> getCheckinHistory(int days) async {
    final db = await _db;
    final startDate = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    final results = await db.query(
      DbConstants.tableDailyCheckins,
      where: 'checkin_date >= ?',
      whereArgs: [startDate],
      orderBy: 'checkin_date ASC',
    );

    return results.map((row) {
      return CheckinRecord(
        id: row['id'] as int,
        checkinDate: row['checkin_date'] as String,
        newWords: row['new_words'] as int,
        reviewWords: row['review_words'] as int,
        correctRate: (row['correct_rate'] as num).toDouble(),
        studyMinutes: row['study_minutes'] as int,
        streakDays: row['streak_days'] as int,
        achievements: row['achievements'] != null
            ? (jsonDecode(row['achievements'] as String) as List<dynamic>)
                .cast<String>()
            : [],
      );
    }).toList();
  }

  /// Get total words learned
  Future<int> getTotalWordsLearned() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableUserProgress} WHERE is_new = 0',
    );
    return result.first['cnt'] as int;
  }

  /// Get total study days
  Future<int> getTotalStudyDays() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableDailyCheckins}',
    );
    return result.first['cnt'] as int;
  }

  /// Check and unlock achievements
  Future<List<String>> _checkAchievements({
    required int streakDays,
    required int newWords,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final unlocked = <String>[];

    // Streak achievements
    final streakAchievements = {
      'streak_1': 1,
      'streak_3': 3,
      'streak_7': 7,
      'streak_30': 30,
      'streak_100': 100,
    };

    for (final entry in streakAchievements.entries) {
      if (streakDays >= entry.value) {
        final result = await db.query(
          DbConstants.tableAchievements,
          where: 'achievement_key = ? AND unlocked_at IS NULL',
          whereArgs: [entry.key],
        );
        if (result.isNotEmpty) {
          await db.update(
            DbConstants.tableAchievements,
            {'unlocked_at': now, 'progress': entry.value},
            where: 'achievement_key = ?',
            whereArgs: [entry.key],
          );
          unlocked.add(entry.key);
        }
      }
      // Update progress
      await db.update(
        DbConstants.tableAchievements,
        {'progress': streakDays},
        where: 'achievement_key = ?',
        whereArgs: [entry.key],
      );
    }

    // Words learned achievements
    final totalWords = await getTotalWordsLearned();
    final wordAchievements = {
      'words_100': 100,
      'words_500': 500,
      'words_2000': 2000,
    };

    for (final entry in wordAchievements.entries) {
      if (totalWords >= entry.value) {
        final result = await db.query(
          DbConstants.tableAchievements,
          where: 'achievement_key = ? AND unlocked_at IS NULL',
          whereArgs: [entry.key],
        );
        if (result.isNotEmpty) {
          await db.update(
            DbConstants.tableAchievements,
            {'unlocked_at': now, 'progress': totalWords},
            where: 'achievement_key = ?',
            whereArgs: [entry.key],
          );
          unlocked.add(entry.key);
        }
      }
      await db.update(
        DbConstants.tableAchievements,
        {'progress': totalWords},
        where: 'achievement_key = ?',
        whereArgs: [entry.key],
      );
    }

    return unlocked;
  }
}
