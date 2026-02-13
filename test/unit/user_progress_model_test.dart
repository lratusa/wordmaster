import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/features/study/domain/models/user_progress.dart';

void main() {
  group('UserProgress', () {
    group('constructor defaults', () {
      test('has correct default values', () {
        final p = UserProgress(
          wordId: 1,
          fsrsCardJson: '{}',
          dueDate: DateTime(2025, 1, 1),
        );

        expect(p.id, isNull);
        expect(p.wordId, 1);
        expect(p.stability, 0);
        expect(p.difficulty, 0);
        expect(p.state, 0);
        expect(p.reps, 0);
        expect(p.lapses, 0);
        expect(p.reviewCount, 0);
        expect(p.correctCount, 0);
        expect(p.lastReviewedAt, isNull);
        expect(p.isStarred, false);
        expect(p.isNew, true);
        expect(p.masteryLevel, 0);
        expect(p.lastQuizType, isNull);
      });
    });

    group('toMap', () {
      test('converts all fields to map', () {
        final date = DateTime.utc(2025, 6, 15, 10, 30);
        final reviewDate = DateTime.utc(2025, 6, 14, 8, 0);
        final p = UserProgress(
          id: 42,
          wordId: 7,
          fsrsCardJson: '{"key":"value"}',
          dueDate: date,
          stability: 1.5,
          difficulty: 0.3,
          state: 2,
          reps: 5,
          lapses: 1,
          reviewCount: 10,
          correctCount: 8,
          lastReviewedAt: reviewDate,
          isStarred: true,
          isNew: false,
          masteryLevel: 3,
          lastQuizType: 'quiz',
        );

        final map = p.toMap();
        expect(map['id'], 42);
        expect(map['word_id'], 7);
        expect(map['fsrs_card_json'], '{"key":"value"}');
        expect(map['stability'], 1.5);
        expect(map['difficulty'], 0.3);
        expect(map['state'], 2);
        expect(map['reps'], 5);
        expect(map['lapses'], 1);
        expect(map['review_count'], 10);
        expect(map['correct_count'], 8);
        expect(map['is_starred'], 1);
        expect(map['is_new'], 0);
        expect(map['mastery_level'], 3);
        expect(map['last_quiz_type'], 'quiz');
      });

      test('stores dueDate as UTC ISO-8601', () {
        final localDate = DateTime(2025, 6, 15, 10, 30);
        final p = UserProgress(
          wordId: 1,
          fsrsCardJson: '{}',
          dueDate: localDate,
        );
        final map = p.toMap();
        final stored = map['due_date'] as String;
        expect(stored, contains('Z'));
        expect(DateTime.parse(stored).isUtc, true);
      });

      test('stores lastReviewedAt as UTC ISO-8601', () {
        final reviewDate = DateTime(2025, 3, 10, 14, 0);
        final p = UserProgress(
          wordId: 1,
          fsrsCardJson: '{}',
          dueDate: DateTime(2025, 1, 1),
          lastReviewedAt: reviewDate,
        );
        final map = p.toMap();
        final stored = map['last_reviewed_at'] as String;
        expect(stored, contains('Z'));
      });

      test('omits id when null', () {
        final p = UserProgress(
          wordId: 1,
          fsrsCardJson: '{}',
          dueDate: DateTime(2025, 1, 1),
        );
        expect(p.toMap().containsKey('id'), false);
      });

      test('lastReviewedAt is null when not set', () {
        final p = UserProgress(
          wordId: 1,
          fsrsCardJson: '{}',
          dueDate: DateTime(2025, 1, 1),
        );
        expect(p.toMap()['last_reviewed_at'], isNull);
      });
    });

    group('fromMap', () {
      test('parses all fields from map', () {
        final map = {
          'id': 10,
          'word_id': 3,
          'fsrs_card_json': '{"card":true}',
          'due_date': '2025-06-15T10:30:00.000Z',
          'stability': 2.5,
          'difficulty': 0.7,
          'state': 1,
          'reps': 3,
          'lapses': 0,
          'review_count': 5,
          'correct_count': 4,
          'last_reviewed_at': '2025-06-14T08:00:00.000Z',
          'is_starred': 1,
          'is_new': 0,
          'mastery_level': 2,
          'last_quiz_type': 'flashcard',
        };

        final p = UserProgress.fromMap(map);
        expect(p.id, 10);
        expect(p.wordId, 3);
        expect(p.fsrsCardJson, '{"card":true}');
        expect(p.dueDate.year, 2025);
        expect(p.stability, 2.5);
        expect(p.difficulty, 0.7);
        expect(p.state, 1);
        expect(p.reps, 3);
        expect(p.lapses, 0);
        expect(p.reviewCount, 5);
        expect(p.correctCount, 4);
        expect(p.lastReviewedAt, isNotNull);
        expect(p.isStarred, true);
        expect(p.isNew, false);
        expect(p.masteryLevel, 2);
        expect(p.lastQuizType, 'flashcard');
      });

      test('handles null/missing optional fields with defaults', () {
        final map = {
          'word_id': 1,
          'fsrs_card_json': '{}',
          'due_date': '2025-01-01T00:00:00.000Z',
        };

        final p = UserProgress.fromMap(map);
        expect(p.id, isNull);
        expect(p.stability, 0);
        expect(p.difficulty, 0);
        expect(p.state, 0);
        expect(p.reps, 0);
        expect(p.lapses, 0);
        expect(p.reviewCount, 0);
        expect(p.correctCount, 0);
        expect(p.lastReviewedAt, isNull);
        expect(p.isStarred, false);
        expect(p.isNew, true);
        expect(p.masteryLevel, 0);
        expect(p.lastQuizType, isNull);
      });
    });

    group('toMap/fromMap roundtrip', () {
      test('preserves all data through roundtrip', () {
        final original = UserProgress(
          id: 5,
          wordId: 42,
          fsrsCardJson: '{"test":"data"}',
          dueDate: DateTime.utc(2025, 7, 20, 12, 0),
          stability: 3.14,
          difficulty: 0.618,
          state: 2,
          reps: 10,
          lapses: 2,
          reviewCount: 15,
          correctCount: 12,
          lastReviewedAt: DateTime.utc(2025, 7, 19, 9, 30),
          isStarred: true,
          isNew: false,
          masteryLevel: 4,
          lastQuizType: 'quiz',
        );

        final restored = UserProgress.fromMap(original.toMap());
        expect(restored.id, original.id);
        expect(restored.wordId, original.wordId);
        expect(restored.fsrsCardJson, original.fsrsCardJson);
        expect(restored.stability, original.stability);
        expect(restored.difficulty, original.difficulty);
        expect(restored.state, original.state);
        expect(restored.reps, original.reps);
        expect(restored.lapses, original.lapses);
        expect(restored.reviewCount, original.reviewCount);
        expect(restored.correctCount, original.correctCount);
        expect(restored.isStarred, original.isStarred);
        expect(restored.isNew, original.isNew);
        expect(restored.masteryLevel, original.masteryLevel);
        expect(restored.lastQuizType, original.lastQuizType);
      });
    });

    group('copyWith', () {
      test('copies with changed fields', () {
        final p = UserProgress(
          wordId: 1,
          fsrsCardJson: '{}',
          dueDate: DateTime(2025, 1, 1),
          isStarred: false,
          isNew: true,
        );

        final updated = p.copyWith(
          isStarred: true,
          isNew: false,
          reviewCount: 5,
        );

        expect(updated.wordId, 1); // unchanged
        expect(updated.isStarred, true);
        expect(updated.isNew, false);
        expect(updated.reviewCount, 5);
      });

      test('preserves unchanged fields', () {
        final p = UserProgress(
          id: 3,
          wordId: 7,
          fsrsCardJson: '{"a":1}',
          dueDate: DateTime(2025, 5, 5),
          stability: 2.0,
          masteryLevel: 3,
        );

        final updated = p.copyWith(reps: 10);
        expect(updated.id, 3);
        expect(updated.wordId, 7);
        expect(updated.fsrsCardJson, '{"a":1}');
        expect(updated.stability, 2.0);
        expect(updated.masteryLevel, 3);
        expect(updated.reps, 10);
      });
    });
  });
}
