import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/features/study/application/study_session_notifier.dart';
import 'package:wordmaster/src/features/study/domain/models/user_progress.dart';
import 'package:wordmaster/src/features/word_lists/domain/enums/language.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word.dart';

void main() {
  group('StudySessionState', () {
    group('constructor defaults', () {
      test('has correct default values', () {
        const state = StudySessionState();
        expect(state.isLoading, true);
        expect(state.isCompleted, false);
        expect(state.queue, isEmpty);
        expect(state.currentIndex, 0);
        expect(state.isAnswerShown, false);
        expect(state.sessionId, 0);
        expect(state.newWordsCount, 0);
        expect(state.reviewWordsCount, 0);
        expect(state.correctCount, 0);
        expect(state.incorrectCount, 0);
        expect(state.starredCount, 0);
        expect(state.startedAt, isNull);
      });
    });

    group('computed properties', () {
      test('currentItem returns null for empty queue', () {
        const state = StudySessionState();
        expect(state.currentItem, isNull);
      });

      test('currentItem returns correct item', () {
        final item = _makeStudyItem('apple');
        final state = StudySessionState(
          queue: [item],
          currentIndex: 0,
          isLoading: false,
        );
        expect(state.currentItem, isNotNull);
        expect(state.currentItem!.word.word, 'apple');
      });

      test('currentItem returns null when index out of bounds', () {
        final item = _makeStudyItem('test');
        final state = StudySessionState(
          queue: [item],
          currentIndex: 1,
          isLoading: false,
        );
        expect(state.currentItem, isNull);
      });

      test('totalReviewed sums correct and incorrect', () {
        const state = StudySessionState(
          correctCount: 7,
          incorrectCount: 3,
        );
        expect(state.totalReviewed, 10);
      });

      test('totalWords returns queue length', () {
        final state = StudySessionState(
          queue: [_makeStudyItem('a'), _makeStudyItem('b'), _makeStudyItem('c')],
        );
        expect(state.totalWords, 3);
      });

      test('correctRate returns 0 when no reviews', () {
        const state = StudySessionState();
        expect(state.correctRate, 0);
      });

      test('correctRate calculates correctly', () {
        const state = StudySessionState(
          correctCount: 3,
          incorrectCount: 1,
        );
        expect(state.correctRate, 0.75);
      });

      test('durationSeconds returns 0 when startedAt is null', () {
        const state = StudySessionState();
        expect(state.durationSeconds, 0);
      });
    });

    group('copyWith', () {
      test('copies with changed fields', () {
        const state = StudySessionState();
        final updated = state.copyWith(
          isLoading: false,
          isCompleted: true,
          correctCount: 5,
        );
        expect(updated.isLoading, false);
        expect(updated.isCompleted, true);
        expect(updated.correctCount, 5);
        expect(updated.incorrectCount, 0); // unchanged
      });
    });
  });

  group('StudySettings', () {
    test('has correct default values', () {
      const s = StudySettings(wordListId: 1);
      expect(s.wordListId, 1);
      expect(s.newWordsLimit, 10);
      expect(s.reviewLimit, 200);
      expect(s.studyOrder, StudyOrder.random);
      expect(s.studyMode, StudyMode.mixed);
      expect(s.quizFormat, QuizFormat.flashcard);
    });

    test('accepts custom values', () {
      const s = StudySettings(
        wordListId: 5,
        newWordsLimit: 20,
        reviewLimit: 50,
        studyOrder: StudyOrder.sequential,
        studyMode: StudyMode.newOnly,
        quizFormat: QuizFormat.quiz,
      );
      expect(s.wordListId, 5);
      expect(s.newWordsLimit, 20);
      expect(s.reviewLimit, 50);
      expect(s.studyOrder, StudyOrder.sequential);
      expect(s.studyMode, StudyMode.newOnly);
      expect(s.quizFormat, QuizFormat.quiz);
    });
  });

  group('StudyMode enum', () {
    test('has all expected values', () {
      expect(StudyMode.values.length, 3);
      expect(StudyMode.values, contains(StudyMode.mixed));
      expect(StudyMode.values, contains(StudyMode.newOnly));
      expect(StudyMode.values, contains(StudyMode.reviewOnly));
    });
  });

  group('StudyOrder enum', () {
    test('has all expected values', () {
      expect(StudyOrder.values.length, 2);
      expect(StudyOrder.values, contains(StudyOrder.sequential));
      expect(StudyOrder.values, contains(StudyOrder.random));
    });
  });

  group('QuizFormat enum', () {
    test('has all expected values', () {
      expect(QuizFormat.values.length, 4);
      expect(QuizFormat.values, contains(QuizFormat.flashcard));
      expect(QuizFormat.values, contains(QuizFormat.quiz));
      expect(QuizFormat.values, contains(QuizFormat.kanjiReading));
      expect(QuizFormat.values, contains(QuizFormat.kanjiSelection));
    });
  });

  group('StudyItem', () {
    test('stores word, progress, and isNewWord', () {
      final word = Word(
        wordListId: 1,
        language: Language.en,
        word: 'hello',
        translationCn: '你好',
      );
      final progress = UserProgress(
        wordId: 1,
        fsrsCardJson: '{}',
        dueDate: DateTime(2025, 1, 1),
      );
      final item = StudyItem(
        word: word,
        progress: progress,
        isNewWord: true,
      );
      expect(item.word.word, 'hello');
      expect(item.progress.wordId, 1);
      expect(item.isNewWord, true);
    });
  });
}

/// Helper to create a StudyItem for testing.
StudyItem _makeStudyItem(String wordText) {
  return StudyItem(
    word: Word(
      wordListId: 1,
      language: Language.en,
      word: wordText,
      translationCn: '翻译',
    ),
    progress: UserProgress(
      wordId: 1,
      fsrsCardJson: '{}',
      dueDate: DateTime(2025, 1, 1),
    ),
    isNewWord: true,
  );
}
