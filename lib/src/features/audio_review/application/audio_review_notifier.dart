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

/// Playback phase - what's currently being played
enum PlaybackPhase {
  /// Not playing anything
  idle,
  /// Playing the word
  playingWord,
  /// Playing the example sentence
  playingSentence,
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
  final DateTime? startedAt;
  final bool isPlaying;
  final PlaybackPhase playbackPhase;  // Current playback phase
  final String? errorMessage;  // Error message for unsupported features

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
    this.startedAt,
    this.isPlaying = false,
    this.playbackPhase = PlaybackPhase.idle,
    this.errorMessage,
  });

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
    PlaybackPhase? playbackPhase,
    String? errorMessage,
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
      playbackPhase: playbackPhase ?? this.playbackPhase,
      errorMessage: errorMessage ?? this.errorMessage,
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

  FsrsService? _fsrsService;
  ProgressRepository? _progressRepo;
  SessionRepository? _sessionRepo;
  WordRepository? _wordRepo;
  TtsService? _ttsService;

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
      var wordIds = await _progressRepo!.getDueWordIds(settings.wordListId);

      // If no due words, get any learned words
      if (wordIds.isEmpty) {
        wordIds = await _progressRepo!.getLearnedWordIds(
          settings.wordListId,
          limit: settings.wordLimit,
        );
      }

      wordIds = wordIds.take(settings.wordLimit).toList();

      final queue = <StudyItem>[];
      for (final wordId in wordIds) {
        final word = await _wordRepo!.getWordById(wordId);
        if (word != null) {
          // Check if the language is supported by TTS
          if (!_ttsService!.isLanguageSupported(word.language.code)) {
            // Skip words with unsupported languages, but track that we encountered them
            continue;
          }
          final progress = await _progressRepo!.getOrCreateProgress(word.id!);
          queue.add(StudyItem(word: word, progress: progress, isNewWord: false));
        }
      }

      if (queue.isEmpty) {
        // Check if we had words but they were all filtered out due to language
        if (wordIds.isNotEmpty) {
          state = state.copyWith(
            isLoading: false,
            isCompleted: true,
            errorMessage: '听力练习暂不支持日语，敬请期待',  // Audio review doesn't support Japanese yet
          );
        } else {
          state = state.copyWith(isLoading: false, isCompleted: true);
        }
        return;
      }

      final sessionId = await _sessionRepo!.createSession(
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

  /// Play the current word and example sentence via TTS
  /// Flow: word → pause → example sentence → done
  Future<void> _playCurrentWord() async {
    final item = state.currentItem;
    if (item == null) return;

    // Play the word first
    state = state.copyWith(isPlaying: true, playbackPhase: PlaybackPhase.playingWord);
    await _ttsService?.speak(item.word.word, language: item.word.language.code);

    // Short pause between word and sentence
    await Future.delayed(const Duration(milliseconds: 800));

    // Play the first example sentence if available
    if (item.word.exampleSentences.isNotEmpty) {
      state = state.copyWith(playbackPhase: PlaybackPhase.playingSentence);
      final sentence = item.word.exampleSentences.first.sentence;
      await _ttsService?.speak(sentence, language: item.word.language.code);
    }

    state = state.copyWith(isPlaying: false, playbackPhase: PlaybackPhase.idle);

    // In auto mode, schedule answer reveal
    if (state.mode == AudioMode.auto) {
      _autoTimer?.cancel();
      _autoTimer = Timer(const Duration(seconds: 3), () {
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

  /// Replay the current word and example sentence
  Future<void> replay() async {
    final item = state.currentItem;
    if (item == null) return;

    // Play the word first
    state = state.copyWith(isPlaying: true, playbackPhase: PlaybackPhase.playingWord);
    await _ttsService?.speak(item.word.word, language: item.word.language.code);

    // Short pause between word and sentence
    await Future.delayed(const Duration(milliseconds: 800));

    // Play the first example sentence if available
    if (item.word.exampleSentences.isNotEmpty) {
      state = state.copyWith(playbackPhase: PlaybackPhase.playingSentence);
      final sentence = item.word.exampleSentences.first.sentence;
      await _ttsService?.speak(sentence, language: item.word.language.code);
    }

    state = state.copyWith(isPlaying: false, playbackPhase: PlaybackPhase.idle);
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
    final result = _fsrsService!.review(card, ratingEnum);

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
    await _progressRepo!.updateProgress(updatedProgress);

    // Log review
    await _sessionRepo!.logReview(
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
      await _sessionRepo!.completeSession(
        sessionId: state.sessionId,
        totalWords: state.totalWords,
        newWords: 0,
        reviewWords: state.totalWords,
        correctCount: newCorrect,
        incorrectCount: newIncorrect,
        starredCount: 0,
        durationSeconds: state.durationSeconds,
      );
      await _ttsService?.stop();
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
    _ttsService?.stop();
  }
}

final audioReviewProvider =
    NotifierProvider<AudioReviewNotifier, AudioReviewState>(
        AudioReviewNotifier.new);
