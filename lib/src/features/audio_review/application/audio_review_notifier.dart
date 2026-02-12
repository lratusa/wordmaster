import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tts_service.dart';
import '../../study/application/study_session_notifier.dart';
import '../../study/data/repositories/progress_repository.dart';
import '../../study/data/repositories/session_repository.dart';
import '../../study/domain/services/fsrs_service.dart';
import '../../word_lists/data/repositories/word_repository.dart';

/// Audio review modes
enum AudioMode {
  /// Manual: play word, user taps to see answer, then rates
  manual,

  /// Auto: play word → pause → play answer → pause → next
  auto,
}

/// Audio review session state
class AudioReviewState {
  final bool isLoading;
  final bool isCompleted;
  final List<StudyItem> queue;
  final int currentIndex;
  final bool isAnswerRevealed;
  final AudioMode mode;
  final int sessionId;
  final int correctCount;
  final int incorrectCount;
  final DateTime startedAt;
  final bool isPlaying;

  const AudioReviewState({
    this.isLoading = true,
    this.isCompleted = false,
    this.queue = const [],
    this.currentIndex = 0,
    this.isAnswerRevealed = false,
    this.mode = AudioMode.manual,
    this.sessionId = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    DateTime? startedAt,
    this.isPlaying = false,
  }) : startedAt = startedAt ?? const _DefaultDateTime();

  AudioReviewState copyWith({
    bool? isLoading,
    bool? isCompleted,
    List<StudyItem>? queue,
    int? currentIndex,
    bool? isAnswerRevealed,
    AudioMode? mode,
    int? sessionId,
    int? correctCount,
    int? incorrectCount,
    DateTime? startedAt,
    bool? isPlaying,
  }) {
    return AudioReviewState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isAnswerRevealed: isAnswerRevealed ?? this.isAnswerRevealed,
      mode: mode ?? this.mode,
      sessionId: sessionId ?? this.sessionId,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      startedAt: startedAt ?? this.startedAt,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  StudyItem? get currentItem =>
      currentIndex < queue.length ? queue[currentIndex] : null;

  int get totalReviewed => correctCount + incorrectCount;
  int get totalWords => queue.length;
  double get correctRate =>
      totalReviewed > 0 ? correctCount / totalReviewed : 0;
  int get durationSeconds =>
      DateTime.now().difference(startedAt).inSeconds;
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return DateTime.now().noSuchMethod(invocation);
  }
}

/// Audio review settings
class AudioReviewSettings {
  final int wordListId;
  final int wordLimit;
  final AudioMode mode;

  const AudioReviewSettings({
    required this.wordListId,
    this.wordLimit = 20,
    this.mode = AudioMode.manual,
  });
}

class AudioReviewNotifier extends Notifier<AudioReviewState> {
  Timer? _autoTimer;

  @override
  AudioReviewState build() {
    ref.onDispose(() => _autoTimer?.cancel());
    return const AudioReviewState();
  }

  late final FsrsService _fsrsService;
  late final ProgressRepository _progressRepo;
  late final SessionRepository _sessionRepo;
  late final WordRepository _wordRepo;
  late final TtsService _ttsService;

  /// Start an audio review session
  Future<void> startSession(AudioReviewSettings settings) async {
    _fsrsService = ref.read(fsrsServiceProvider);
    _progressRepo = ref.read(progressRepositoryProvider);
    _sessionRepo = ref.read(sessionRepositoryProvider);
    _wordRepo = WordRepository();
    _ttsService = ref.read(ttsServiceProvider);

    state = AudioReviewState(
      isLoading: true,
      mode: settings.mode,
      startedAt: DateTime.now(),
    );

    try {
      // First try to get due review words
      var wordIds = await _progressRepo.getDueWordIds(settings.wordListId);

      // If no due words, get any learned words
      if (wordIds.isEmpty) {
        wordIds = await _progressRepo.getLearnedWordIds(
          settings.wordListId,
          limit: settings.wordLimit,
        );
      }

      wordIds = wordIds.take(settings.wordLimit).toList();

      final queue = <StudyItem>[];
      for (final wordId in wordIds) {
        final word = await _wordRepo.getWordById(wordId);
        if (word != null) {
          final progress = await _progressRepo.getOrCreateProgress(word.id!);
          queue.add(StudyItem(word: word, progress: progress, isNewWord: false));
        }
      }

      if (queue.isEmpty) {
        state = state.copyWith(isLoading: false, isCompleted: true);
        return;
      }

      final sessionId = await _sessionRepo.createSession(
        sessionType: 'audio',
        wordListId: settings.wordListId,
      );

      state = state.copyWith(
        isLoading: false,
        queue: queue,
        currentIndex: 0,
        sessionId: sessionId,
      );

      // Play the first word
      _playCurrentWord();
    } catch (e) {
      state = state.copyWith(isLoading: false, isCompleted: true);
    }
  }

  /// Play the current word via TTS
  Future<void> _playCurrentWord() async {
    final item = state.currentItem;
    if (item == null) return;

    state = state.copyWith(isPlaying: true);
    await _ttsService.speak(item.word.word, language: item.word.language.code);
    state = state.copyWith(isPlaying: false);

    // In auto mode, schedule answer reveal
    if (state.mode == AudioMode.auto) {
      _autoTimer?.cancel();
      _autoTimer = Timer(const Duration(seconds: 5), () {
        revealAnswer();
      });
    }
  }

  /// Reveal the answer (translation)
  void revealAnswer() {
    if (state.isAnswerRevealed) return;
    state = state.copyWith(isAnswerRevealed: true);

    // In auto mode, auto-advance after 3 seconds
    if (state.mode == AudioMode.auto) {
      _autoTimer?.cancel();
      _autoTimer = Timer(const Duration(seconds: 3), () {
        rate(true); // Auto-rate as correct in auto mode
      });
    }
  }

  /// Replay the current word
  Future<void> replay() async {
    final item = state.currentItem;
    if (item == null) return;
    await _ttsService.speak(item.word.word, language: item.word.language.code);
  }

  /// Rate the current word (simplified 2-level: correct/incorrect)
  Future<void> rate(bool isCorrect) async {
    _autoTimer?.cancel();
    final item = state.currentItem;
    if (item == null) return;

    // Map to FSRS ratings: correct → Good(3), incorrect → Again(1)
    final rating = isCorrect ? 3 : 1;
    final ratingEnum = FsrsService.intToRating(rating);
    final card = FsrsService.cardFromJson(item.progress.fsrsCardJson);
    final result = _fsrsService.review(card, ratingEnum);

    // Update progress
    final updatedProgress = item.progress.copyWith(
      fsrsCardJson: FsrsService.cardToJson(result.card),
      dueDate: result.card.due,
      stability: result.card.stability ?? 0,
      difficulty: result.card.difficulty ?? 0,
      state: result.card.state.value,
      reps: item.progress.reps + 1,
      lapses: item.progress.lapses + (isCorrect ? 0 : 1),
      reviewCount: item.progress.reviewCount + 1,
      correctCount: item.progress.correctCount + (isCorrect ? 1 : 0),
      lastReviewedAt: DateTime.now(),
      isNew: false,
    );
    await _progressRepo.updateProgress(updatedProgress);

    // Log review
    await _sessionRepo.logReview(
      sessionId: state.sessionId,
      wordId: item.word.id!,
      rating: rating,
      fsrsReviewLogJson: FsrsService.reviewLogToJson(result.reviewLog),
    );

    final newCorrect = state.correctCount + (isCorrect ? 1 : 0);
    final newIncorrect = state.incorrectCount + (isCorrect ? 0 : 1);

    // Re-add incorrect words to the end
    var queue = state.queue;
    if (!isCorrect) {
      queue = [...queue, item];
    }

    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= queue.length) {
      // Session complete
      await _sessionRepo.completeSession(
        sessionId: state.sessionId,
        totalWords: state.totalWords,
        newWords: 0,
        reviewWords: state.totalWords,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        starredCount: 0,
        durationSeconds: state.durationSeconds,
      );
      await _ttsService.stop();
      state = state.copyWith(
        isCompleted: true,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        queue: queue,
      );
    } else {
      state = state.copyWith(
        currentIndex: nextIndex,
        isAnswerRevealed: false,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        queue: queue,
      );
      // Play next word
      _playCurrentWord();
    }
  }

  /// Stop session
  void stopSession() {
    _autoTimer?.cancel();
    _ttsService.stop();
  }
}

final audioReviewProvider =
    NotifierProvider<AudioReviewNotifier, AudioReviewState>(
        AudioReviewNotifier.new);
