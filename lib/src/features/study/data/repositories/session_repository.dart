import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';

class SessionRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Create a new review session, returns the session ID.
  Future<int> createSession({
    required String sessionType,
    String? language,
    int? wordListId,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    return db.insert(DbConstants.tableReviewSessions, {
      'session_date': now.toIso8601String().substring(0, 10),
      'session_type': sessionType,
      'language': language,
      'word_list_id': wordListId,
      'started_at': now.toIso8601String(),
    });
  }

  /// Update session with final stats when completed.
  Future<void> completeSession({
    required int sessionId,
    required int totalWords,
    required int newWords,
    required int reviewWords,
    required int correctCount,
    required int incorrectCount,
    required int starredCount,
    required int durationSeconds,
  }) async {
    final db = await _db;
    await db.update(
      DbConstants.tableReviewSessions,
      {
        'total_words': totalWords,
        'new_words': newWords,
        'review_words': reviewWords,
        'correct_count': correctCount,
        'incorrect_count': incorrectCount,
        'starred_count': starredCount,
        'duration_seconds': durationSeconds,
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Log a single review action.
  Future<void> logReview({
    required int sessionId,
    required int wordId,
    required int rating,
    int? responseTimeMs,
    String? fsrsReviewLogJson,
  }) async {
    final db = await _db;
    await db.insert(DbConstants.tableReviewLogs, {
      'session_id': sessionId,
      'word_id': wordId,
      'rating': rating,
      'response_time_ms': responseTimeMs,
      'fsrs_review_log_json': fsrsReviewLogJson,
    });
  }

  /// Get daily stats for the last [days] days.
  Future<List<({String date, int newWords, int reviewWords, int correctCount, int totalSeconds})>>
      getDailyStats(int days) async {
    final db = await _db;
    final startDate = DateTime.now()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    final results = await db.rawQuery('''
      SELECT
        session_date,
        COALESCE(SUM(new_words), 0) as new_words,
        COALESCE(SUM(review_words), 0) as review_words,
        COALESCE(SUM(correct_count), 0) as correct_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM ${DbConstants.tableReviewSessions}
      WHERE session_date >= ? AND completed_at IS NOT NULL
      GROUP BY session_date
      ORDER BY session_date ASC
    ''', [startDate]);

    return results
        .map((row) => (
              date: row['session_date'] as String,
              newWords: row['new_words'] as int,
              reviewWords: row['review_words'] as int,
              correctCount: row['correct_count'] as int,
              totalSeconds: row['total_seconds'] as int,
            ))
        .toList();
  }

  /// Get all-time aggregate stats.
  Future<({int totalSessions, int totalWords, int totalMinutes, double avgCorrectRate})>
      getAllTimeStats() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT
        COUNT(*) as total_sessions,
        COALESCE(SUM(total_words), 0) as total_words,
        COALESCE(SUM(duration_seconds), 0) as total_seconds,
        CASE WHEN SUM(correct_count + incorrect_count) > 0
          THEN CAST(SUM(correct_count) AS REAL) / SUM(correct_count + incorrect_count)
          ELSE 0
        END as avg_correct_rate
      FROM ${DbConstants.tableReviewSessions}
      WHERE completed_at IS NOT NULL
    ''');

    final row = results.first;
    return (
      totalSessions: row['total_sessions'] as int,
      totalWords: row['total_words'] as int,
      totalMinutes: ((row['total_seconds'] as int) / 60).ceil(),
      avgCorrectRate: (row['avg_correct_rate'] as num).toDouble(),
    );
  }

  /// Get today's session stats.
  /// Includes both completed sessions and a fallback count from review_logs.
  Future<({int newWords, int reviewWords, int correctCount, int totalMinutes})>
      getTodayStats() async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // First try completed sessions
    final sessionResults = await db.rawQuery('''
      SELECT
        COALESCE(SUM(new_words), 0) as new_words,
        COALESCE(SUM(review_words), 0) as review_words,
        COALESCE(SUM(correct_count), 0) as correct_count,
        COALESCE(SUM(duration_seconds), 0) as total_seconds
      FROM ${DbConstants.tableReviewSessions}
      WHERE session_date = ? AND completed_at IS NOT NULL
    ''', [today]);

    final sessionRow = sessionResults.first;
    var newWords = sessionRow['new_words'] as int;
    var reviewWords = sessionRow['review_words'] as int;
    var correctCount = sessionRow['correct_count'] as int;
    var totalSeconds = sessionRow['total_seconds'] as int;

    // If no completed sessions, count from review_logs as fallback
    if (newWords == 0 && reviewWords == 0) {
      final logResults = await db.rawQuery('''
        SELECT
          COUNT(*) as review_count,
          COALESCE(SUM(CASE WHEN rating >= 3 THEN 1 ELSE 0 END), 0) as correct_count
        FROM ${DbConstants.tableReviewLogs}
        WHERE DATE(reviewed_at) = ?
      ''', [today]);

      final logRow = logResults.first;
      final reviewCount = logRow['review_count'] as int;
      correctCount = logRow['correct_count'] as int;

      // Count reviews as "review words" (since we can't tell if they're new)
      reviewWords = reviewCount;
    }

    return (
      newWords: newWords,
      reviewWords: reviewWords,
      correctCount: correctCount,
      totalMinutes: (totalSeconds / 60).ceil(),
    );
  }
}
