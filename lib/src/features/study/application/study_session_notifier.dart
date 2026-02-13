import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tts_service.dart';
import '../../word_lists/data/repositories/word_repository.dart';
import '../../word_lists/domain/models/word.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/models/user_progress.dart';
import '../domain/services/fsrs_service.dart';

// Study session state
class StudySessionState {
  final bool isLoading;
  final bool isCompleted;
  final List<StudyItem> queue;
  final int currentIndex;
  final bool isAnswerShown;
  final int sessionId;
  final int newWordsCount;
  final int reviewWordsCount;
  final int correctCount;
  final int incorrectCount;
  final int starredCount;
  final DateTime? startedAt;

  const StudySessionState({
    this.isLoading = true,
    this.isCompleted = false,
    this.queue = const [],
    this.currentIndex = 0,
    this.isAnswerShown = false,
    this.sessionId = 0,
    this.newWordsCount = 0,
    this.reviewWordsCount = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.starredCount = 0,
    this.startedAt,
  });

  StudySessionState copyWith({
    bool? isLoading,
    bool? isCompleted,
    List<StudyItem>? queue,
    int? currentIndex,
    bool? isAnswerShown,
    int? sessionId,
    int? newWordsCount,
    int? reviewWordsCount,
    int? correctCount,
    int? incorrectCount,
    int? starredCount,
    DateTime? startedAt,
  }) {
    return StudySessionState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isAnswerShown: isAnswerShown ?? this.isAnswerShown,
      sessionId: sessionId ?? this.sessionId,
      newWordsCount: newWordsCount ?? this.newWordsCount,
      reviewWordsCount: reviewWordsCount ?? this.reviewWordsCount,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      starredCount: starredCount ?? this.starredCount,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  StudyItem? get currentItem =>
      currentIndex < queue.length ? queue[currentIndex] : null;

  int get totalReviewed => correctCount + incorrectCount;
  int get totalWords => queue.length;
  double get correctRate =>
      totalReviewed > 0 ? correctCount / totalReviewed : 0;
  int get durationSeconds =>
      startedAt != null ? DateTime.now().difference(startedAt!).inSeconds : 0;
}

// A study item = word + its progress
class StudyItem {
  final Word word;
  final UserProgress progress;
  final bool isNewWord;

  const StudyItem({
    required this.word,
    required this.progress,
    required this.isNewWord,
  });
}

// Study order enum
enum StudyOrder {
  sequential, // 顺序学习
  random,     // 乱序学习
}

// Study mode enum
enum StudyMode {
  mixed,      // 混合 - interleave new + review words
  newOnly,    // 仅新词 - only learn new words
  reviewOnly, // 仅复习 - only review due words
}

// Settings for a study session
class StudySettings {
  final int wordListId;
  final int newWordsLimit;
  final int reviewLimit;
  final StudyOrder studyOrder;
  final StudyMode studyMode;

  const StudySettings({
    required this.wordListId,
    this.newWordsLimit = 10,
    this.reviewLimit = 200,
    this.studyOrder = StudyOrder.random,
    this.studyMode = StudyMode.mixed,
  });
}

// Providers
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

final fsrsServiceProvider = Provider<FsrsService>((ref) {
  return FsrsService();
});

final studySettingsProvider = Provider<StudySettings>((ref) {
  // Default settings - will be overridden when starting a session
  return const StudySettings(wordListId: 0);
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(() => tts.dispose());
  return tts;
});

// The main study session notifier
class StudySessionNotifier extends Notifier<StudySessionState> {
  @override
  StudySessionState build() {
    return const StudySessionState();
  }

  FsrsService? _fsrsService;
  ProgressRepository? _progressRepo;
  SessionRepository? _sessionRepo;
  WordRepository? _wordRepo;

  /// Initialize and start a study session
  Future<void> startSession(StudySettings settings) async {
    _fsrsService = ref.read(fsrsServiceProvider);
    _progressRepo = ref.read(progressRepositoryProvider);
    _sessionRepo = ref.read(sessionRepositoryProvider);
    _wordRepo = WordRepository();

    state = StudySessionState(
      isLoading: true,
      startedAt: DateTime.now(),
    );

    // Get due review words and new words based on study mode
    List<int> dueWordIds = [];
    List<int> newWordIds = [];

    if (settings.studyMode != StudyMode.newOnly) {
      dueWordIds = await _progressRepo!.getDueWordIds(settings.wordListId);
    }
    if (settings.studyMode != StudyMode.reviewOnly) {
      newWordIds = await _progressRepo!.getNewWordIds(
        settings.wordListId,
        limit: settings.newWordsLimit,
      );
    }

    // Build the study queue based on study mode
    final queue = <StudyItem>[];

    // Load review words
    final reviewIds = dueWordIds.take(settings.reviewLimit).toList();

    if (settings.studyMode == StudyMode.newOnly) {
      // New words only mode
      for (final wordId in newWordIds) {
        final word = await _wordRepo!.getWordById(wordId);
        if (word != null) {
          final progress = await _progressRepo!.getOrCreateProgress(word.id!);
          queue.add(StudyItem(word: word, progress: progress, isNewWord: true));
        }
      }
    } else if (settings.studyMode == StudyMode.reviewOnly) {
      // Review only mode
      for (final wordId in reviewIds) {
        final word = await _wordRepo!.getWordById(wordId);
        if (word != null) {
          final progress = await _progressRepo!.getOrCreateProgress(word.id!);
          queue.add(StudyItem(word: word, progress: progress, isNewWord: false));
        }
      }
    } else {
      // Mixed mode - interleave review and new words (1:5 ratio)
      int newIdx = 0;
      int reviewIdx = 0;

      while (reviewIdx < reviewIds.length || newIdx < newWordIds.length) {
        // Add up to 5 review words
        for (int i = 0; i < 5 && reviewIdx < reviewIds.length; i++) {
          final word = await _wordRepo!.getWordById(reviewIds[reviewIdx]);
          if (word != null) {
            final progress =
                await _progressRepo!.getOrCreateProgress(word.id!);
            queue.add(StudyItem(
                word: word, progress: progress, isNewWord: false));
          }
          reviewIdx++;
        }

        // Add 1 new word
        if (newIdx < newWordIds.length) {
          final word = await _wordRepo!.getWordById(newWordIds[newIdx]);
          if (word != null) {
            final progress =
                await _progressRepo!.getOrCreateProgress(word.id!);
            queue.add(
                StudyItem(word: word, progress: progress, isNewWord: true));
          }
          newIdx++;
        }
      }
    }

    if (queue.isEmpty) {
      state = state.copyWith(isLoading: false, isCompleted: true);
      return;
    }

    // Apply study order
    final orderedQueue = settings.studyOrder == StudyOrder.random
        ? (List<StudyItem>.from(queue)..shuffle())
        : queue;

    // Create session in DB
    final sessionId = await _sessionRepo!.createSession(
      sessionType: 'flashcard',
      wordListId: settings.wordListId,
    );

    state = state.copyWith(
      isLoading: false,
      queue: orderedQueue,
      currentIndex: 0,
      sessionId: sessionId,
      newWordsCount: newWordIds.length,
      reviewWordsCount: reviewIds.length,
    );
  }

  /// Show the answer side of the flashcard
  void showAnswer() {
    state = state.copyWith(isAnswerShown: true);
  }

  /// Rate the current card and advance to next
  Future<void> rateCard(int rating) async {
    final item = state.currentItem;
    if (item == null) return;

    final ratingEnum = FsrsService.intToRating(rating);
    final card = FsrsService.cardFromJson(item.progress.fsrsCardJson);
    final result = _fsrsService!.review(card, ratingEnum);

    // Update progress in DB
    final isCorrect = rating >= 3;
    final updatedProgress = item.progress.copyWith(
      fsrsCardJson: FsrsService.cardToJson(result.card),
      dueDate: result.card.due,
      stability: result.card.stability ?? 0,
      difficulty: result.card.difficulty ?? 0,
      state: result.card.state.value,
      reps: item.progress.reps + 1,
      lapses: item.progress.lapses + (rating == 1 ? 1 : 0),
      reviewCount: item.progress.reviewCount + 1,
      correctCount:
          item.progress.correctCount + (isCorrect ? 1 : 0),
      lastReviewedAt: DateTime.now(),
      isNew: false,
    );
    await _progressRepo!.updateProgress(updatedProgress);

    // Log the review
    await _sessionRepo!.logReview(
      sessionId: state.sessionId,
      wordId: item.word.id!,
      rating: rating,
      fsrsReviewLogJson: FsrsService.reviewLogToJson(result.reviewLog),
    );

    // Update state
    final newCorrect =
        state.correctCount + (isCorrect ? 1 : 0);
    final newIncorrect =
        state.incorrectCount + (isCorrect ? 0 : 1);

    // If rated "Again" (1), re-add to end of queue
    var queue = state.queue;
    if (rating == 1) {
      queue = [...queue, item];
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= queue.length) {
      // Session complete
      await _sessionRepo!.completeSession(
        sessionId: state.sessionId,
        totalWords: state.totalWords,
        newWords: state.newWordsCount,
        reviewWords: state.reviewWordsCount,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        starredCount: state.starredCount,
        durationSeconds: state.durationSeconds,
      );
      state = state.copyWith(
        isCompleted: true,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        queue: queue,
      );
    } else {
      state = state.copyWith(
        currentIndex: nextIndex,
        isAnswerShown: false,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        queue: queue,
      );
    }
  }

  /// Toggle star for current word
  Future<void> toggleStar() async {
    final item = state.currentItem;
    if (item == null) return;

    await _progressRepo!.toggleStar(item.word.id!);
    final wasStarred = item.progress.isStarred;
    final starredDelta = wasStarred ? -1 : 1;

    // Update the item in queue
    final updatedQueue = [...state.queue];
    updatedQueue[state.currentIndex] = StudyItem(
      word: item.word,
      progress: item.progress.copyWith(isStarred: !wasStarred),
      isNewWord: item.isNewWord,
    );

    state = state.copyWith(
      queue: updatedQueue,
      starredCount: state.starredCount + starredDelta,
    );
  }
}

final studySessionProvider =
    NotifierProvider<StudySessionNotifier, StudySessionState>(
        StudySessionNotifier.new);
