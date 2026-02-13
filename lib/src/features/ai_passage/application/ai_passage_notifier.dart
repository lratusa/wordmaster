import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/db_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/deepseek_service.dart';
import '../../../core/services/ai/ollama_service.dart';
import '../../../core/services/ai/openai_service.dart';
import '../../study/application/study_session_notifier.dart'
    show progressRepositoryProvider;
import '../../word_lists/data/repositories/word_repository.dart';
import '../../word_lists/domain/models/word.dart';
import '../domain/passage_history.dart';

/// AI backend type
enum AiBackend { openai, deepseek, ollama }

/// AI passage state
class AiPassageState {
  final bool isLoading;
  final String? error;
  final PassageResult? passage;
  final String language;
  final List<int> sourceWordIds;
  final List<int?> userAnswers;
  final bool isQuizComplete;
  final int? score;
  final int? passageId;

  /// When no API key is set, this holds the prompt for manual copy-paste
  final String? promptText;
  final bool isManualMode;

  /// Whether this is a review/redo of a historical passage
  final bool isReviewMode;

  const AiPassageState({
    this.isLoading = false,
    this.error,
    this.passage,
    this.language = 'en',
    this.sourceWordIds = const [],
    this.userAnswers = const [],
    this.isQuizComplete = false,
    this.score,
    this.passageId,
    this.promptText,
    this.isManualMode = false,
    this.isReviewMode = false,
  });

  AiPassageState copyWith({
    bool? isLoading,
    String? error,
    PassageResult? passage,
    String? language,
    List<int>? sourceWordIds,
    List<int?>? userAnswers,
    bool? isQuizComplete,
    int? score,
    int? passageId,
    String? promptText,
    bool? isManualMode,
    bool? isReviewMode,
  }) {
    return AiPassageState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      passage: passage ?? this.passage,
      language: language ?? this.language,
      sourceWordIds: sourceWordIds ?? this.sourceWordIds,
      userAnswers: userAnswers ?? this.userAnswers,
      isQuizComplete: isQuizComplete ?? this.isQuizComplete,
      score: score ?? this.score,
      passageId: passageId ?? this.passageId,
      promptText: promptText,
      isManualMode: isManualMode ?? this.isManualMode,
      isReviewMode: isReviewMode ?? this.isReviewMode,
    );
  }
}

class AiPassageNotifier extends Notifier<AiPassageState> {
  @override
  AiPassageState build() {
    return const AiPassageState();
  }

  /// Reset to initial state (language selection)
  void reset() {
    state = const AiPassageState();
  }

  /// Generate a passage for the given language
  Future<void> generatePassage(String language, {bool forceNew = false}) async {
    state = AiPassageState(isLoading: true, language: language);

    try {
      // Check cache first (unless forcing new)
      if (!forceNew) {
        final cached = await _getCachedPassage(language);
        if (cached != null) {
          final questions = cached.passage?.questions ?? [];
          state = AiPassageState(
            passage: cached.passage,
            language: language,
            sourceWordIds: cached.sourceWordIds,
            passageId: cached.passageId,
            userAnswers: List.filled(questions.length, null),
          );
          return;
        }
      }

      // Select words for the passage
      final words = await _selectWords(language);
      if (words.isEmpty) {
        state = AiPassageState(
          error: '需要先学习一些单词',
          language: language,
        );
        return;
      }

      // Get AI service - if none configured, show prompt for manual copy-paste
      final aiService = await _getAiService();
      if (aiService == null) {
        // Generate prompt for manual use with any web-based LLM
        final promptHelper = _PromptHelper();
        final prompt = promptHelper.buildPrompt(words, language);
        state = AiPassageState(
          language: language,
          sourceWordIds: words.map((w) => w.id!).toList(),
          promptText: prompt,
          isManualMode: true,
        );
        return;
      }

      // Generate via API
      final result = await aiService.generatePassage(
        words: words,
        language: language,
      );

      final sourceWordIds = words.map((w) => w.id!).toList();

      // Cache result and get the ID
      final passageId = await _cachePassage(language, result, sourceWordIds);

      state = AiPassageState(
        passage: result,
        language: language,
        sourceWordIds: sourceWordIds,
        passageId: passageId,
        userAnswers: List.filled(result.questions.length, null),
      );
    } catch (e) {
      state = AiPassageState(
        error: 'AI 生成失败: $e',
        language: language,
      );
    }
  }

  /// Parse a response pasted by the user from a web-based LLM
  Future<void> parseManualResponse(String responseText) async {
    try {
      // Try to extract JSON from the response
      var jsonStr = responseText.trim();
      // Handle cases where response is wrapped in markdown code blocks
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!.trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = PassageResult.fromJson(json);

      // Cache it and get the ID
      final passageId = await _cachePassage(state.language, result, state.sourceWordIds);

      state = AiPassageState(
        passage: result,
        language: state.language,
        sourceWordIds: state.sourceWordIds,
        passageId: passageId,
        userAnswers: List.filled(result.questions.length, null),
      );
    } catch (e) {
      state = state.copyWith(
        error: '解析失败，请确保粘贴的是完整的 JSON 响应: $e',
      );
    }
  }

  /// Answer a quiz question
  void answerQuestion(int questionIndex, int answerIndex) {
    final answers = [...state.userAnswers];
    answers[questionIndex] = answerIndex;

    // Check if quiz is complete
    final isComplete = answers.every((a) => a != null);
    int? score;
    if (isComplete && state.passage != null) {
      int correct = 0;
      for (int i = 0; i < state.passage!.questions.length; i++) {
        if (answers[i] == state.passage!.questions[i].correctIndex) {
          correct++;
        }
      }
      score = correct;
    }

    state = state.copyWith(
      userAnswers: answers,
      isQuizComplete: isComplete,
      score: score,
    );
  }

  /// Save the quiz score to database
  Future<void> saveQuizScore() async {
    if (state.passageId == null || state.score == null) return;

    final userAnswers = state.userAnswers
        .map((a) => a ?? -1)
        .toList();

    await DatabaseHelper.instance.savePassageScore(
      state.passageId!,
      state.score!,
      userAnswers,
    );
  }

  /// Load a historical passage for review/redo
  Future<void> loadPassageForReview(int passageId) async {
    state = const AiPassageState(isLoading: true, isReviewMode: true);

    try {
      final result = await DatabaseHelper.instance.getPassageById(passageId);
      if (result == null) {
        state = const AiPassageState(error: '短文不存在');
        return;
      }

      final questions = result.passage.questions;
      state = AiPassageState(
        passage: result.passage,
        language: 'en', // Will be determined from passage
        sourceWordIds: result.sourceWordIds,
        passageId: result.id,
        userAnswers: List.filled(questions.length, null),
        isReviewMode: true,
      );
    } catch (e) {
      state = AiPassageState(error: '加载失败: $e');
    }
  }

  /// Get all passage history
  Future<List<PassageHistory>> getPassageHistory() async {
    return DatabaseHelper.instance.getAllPassageHistory();
  }

  /// Delete a passage from history
  Future<void> deletePassage(int passageId) async {
    await DatabaseHelper.instance.deletePassage(passageId);
  }

  Future<List<Word>> _selectWords(String language) async {
    final progressRepo = ref.read(progressRepositoryProvider);
    final wordRepo = WordRepository();

    // Priority: starred > recently wrong > new words
    final starredIds = await progressRepo.getStarredWordIds();
    final words = <Word>[];

    for (final id in starredIds.take(4)) {
      final word = await wordRepo.getWordById(id);
      if (word != null && word.language.code == language) {
        words.add(word);
      }
    }

    // Fill up to 8-12 words from recent review
    if (words.length < 8) {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT w.* FROM ${DbConstants.tableWords} w
        INNER JOIN ${DbConstants.tableUserProgress} up ON w.id = up.word_id
        WHERE w.language = ? AND up.is_new = 0
        ORDER BY up.last_reviewed_at DESC
        LIMIT ?
      ''', [language, 12 - words.length]);

      for (final row in results) {
        final word = Word.fromMap(row);
        if (!words.any((w) => w.id == word.id)) {
          words.add(word);
        }
      }
    }

    return words;
  }

  Future<AiService?> _getAiService() async {
    final db = await DatabaseHelper.instance.database;
    final settings = await db.query(DbConstants.tableSettings);
    final settingsMap = {
      for (final s in settings) s['key'] as String: s['value'] as String
    };

    final backend = settingsMap['ai_backend'] ?? 'openai';
    final apiKey = settingsMap['ai_api_key'] ?? '';

    switch (backend) {
      case 'deepseek':
        if (apiKey.isEmpty) return null;
        return DeepSeekService(apiKey: apiKey);
      case 'ollama':
        final url = settingsMap['ollama_url'] ?? 'http://localhost:11434';
        final model = settingsMap['ollama_model'] ?? 'qwen2.5:7b';
        return OllamaService(baseUrl: url, model: model);
      case 'openai':
      default:
        if (apiKey.isEmpty) return null;
        final model = settingsMap['openai_model'] ?? 'gpt-4o-mini';
        return OpenAiService(apiKey: apiKey, model: model);
    }
  }

  Future<({PassageResult? passage, List<int> sourceWordIds, int? passageId})?> _getCachedPassage(
      String language) async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.query(
      DbConstants.tableGeneratedPassages,
      where: 'generation_date = ? AND language = ?',
      whereArgs: [today, language],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final passage = PassageResult(
      passage: row['passage_text'] as String,
      translation: row['passage_translation'] as String? ?? '',
      questions: (jsonDecode(row['questions_json'] as String) as List<dynamic>)
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );

    final sourceWordIds = (jsonDecode(row['source_word_ids'] as String) as List<dynamic>)
        .map((id) => id as int)
        .toList();

    return (
      passage: passage,
      sourceWordIds: sourceWordIds,
      passageId: row['id'] as int,
    );
  }

  Future<int> _cachePassage(
      String language, PassageResult result, List<int> sourceWordIds) async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final id = await db.insert(DbConstants.tableGeneratedPassages, {
      'generation_date': today,
      'language': language,
      'passage_text': result.passage,
      'passage_translation': result.translation,
      'questions_json': jsonEncode(result.questions.map((q) => q.toJson()).toList()),
      'source_word_ids': jsonEncode(sourceWordIds),
    });

    return id;
  }
}

final aiPassageProvider =
    NotifierProvider<AiPassageNotifier, AiPassageState>(AiPassageNotifier.new);

/// Helper to build prompts (reuses AiService logic without needing an instance)
class _PromptHelper extends AiService {
  @override
  Future<PassageResult> generatePassage({
    required List<Word> words,
    required String language,
  }) {
    throw UnimplementedError('Not used - only prompt building');
  }
}
