import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/models/user_progress.dart';
import '../../domain/services/fsrs_service.dart';

class ProgressRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Get or create progress for a word. If new, initializes FSRS card.
  Future<UserProgress> getOrCreateProgress(int wordId) async {
    final db = await _db;
    final results = await db.query(
      DbConstants.tableUserProgress,
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    if (results.isNotEmpty) {
      return UserProgress.fromMap(results.first);
    }

    // Create new progress with fresh FSRS card
    final card = FsrsService.createNewCard(wordId);
    final progress = UserProgress(
      wordId: wordId,
      fsrsCardJson: FsrsService.cardToJson(card),
      dueDate: card.due,
      stability: card.stability ?? 0,
      difficulty: card.difficulty ?? 0,
      state: card.state.value,
      reps: 0,
      lapses: 0,
      reviewCount: 0,
      correctCount: 0,
      isStarred: false,
      isNew: true,
    );

    final id = await db.insert(
      DbConstants.tableUserProgress,
      progress.toMap(),
    );

    return progress.copyWith(id: id);
  }

  /// Update progress after a review
  Future<void> updateProgress(UserProgress progress) async {
    final db = await _db;
    await db.update(
      DbConstants.tableUserProgress,
      progress.toMap(),
      where: 'id = ?',
      whereArgs: [progress.id],
    );
  }

  /// Get all words due for review in a word list
  Future<List<int>> getDueWordIds(int wordListId) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    final results = await db.rawQuery('''
      SELECT up.word_id FROM ${DbConstants.tableUserProgress} up
      INNER JOIN ${DbConstants.tableWords} w ON up.word_id = w.id
      WHERE w.word_list_id = ? AND up.due_date <= ? AND up.is_new = 0
      ORDER BY up.due_date
    ''', [wordListId, now]);

    return results.map((r) => r['word_id'] as int).toList();
  }

  /// Get new (unlearned) word IDs from a word list
  Future<List<int>> getNewWordIds(int wordListId, {int limit = 10}) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT w.id FROM ${DbConstants.tableWords} w
      LEFT JOIN ${DbConstants.tableUserProgress} up ON w.id = up.word_id
      WHERE w.word_list_id = ? AND (up.id IS NULL OR up.is_new = 1)
      ORDER BY w.id
      LIMIT ?
    ''', [wordListId, limit]);

    return results.map((r) => r['id'] as int).toList();
  }

  /// Toggle star status
  Future<void> toggleStar(int wordId) async {
    final db = await _db;
    final progress = await getOrCreateProgress(wordId);
    await db.update(
      DbConstants.tableUserProgress,
      {'is_starred': progress.isStarred ? 0 : 1},
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// Get all learned word IDs from a word list (for audio review)
  Future<List<int>> getLearnedWordIds(int wordListId, {int limit = 50}) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT up.word_id FROM ${DbConstants.tableUserProgress} up
      INNER JOIN ${DbConstants.tableWords} w ON up.word_id = w.id
      WHERE w.word_list_id = ? AND up.is_new = 0
      ORDER BY up.last_reviewed_at DESC
      LIMIT ?
    ''', [wordListId, limit]);

    return results.map((r) => r['word_id'] as int).toList();
  }

  /// Get starred word IDs
  Future<List<int>> getStarredWordIds() async {
    final db = await _db;
    final results = await db.query(
      DbConstants.tableUserProgress,
      columns: ['word_id'],
      where: 'is_starred = 1',
    );
    return results.map((r) => r['word_id'] as int).toList();
  }

  /// Get total learned words count
  Future<int> getTotalLearnedCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbConstants.tableUserProgress} WHERE is_new = 0',
    );
    return result.first['cnt'] as int;
  }

  /// Get today's review count
  Future<int> getTodayReviewCount() async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM ${DbConstants.tableReviewLogs} WHERE reviewed_at LIKE '$today%'",
    );
    return result.first['cnt'] as int;
  }
}
