import '../../../features/word_lists/domain/models/word.dart';

/// Result from AI passage generation
class PassageResult {
  final String passage;
  final String translation;
  final List<QuizQuestion> questions;

  const PassageResult({
    required this.passage,
    required this.translation,
    required this.questions,
  });

  factory PassageResult.fromJson(Map<String, dynamic> json) {
    return PassageResult(
      passage: json['passage'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) =>
                  QuizQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'passage': passage,
        'translation': translation,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => o.toString())
              .toList() ??
          [],
      correctIndex: json['correct_index'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        'explanation': explanation,
      };
}

/// Abstract AI service interface
abstract class AiService {
  /// Generate a passage using the given words.
  /// [language] is 'en' or 'ja'.
  Future<PassageResult> generatePassage({
    required List<Word> words,
    required String language,
  });

  /// Build the prompt for passage generation.
  String buildPrompt(List<Word> words, String language) {
    final wordList = words.map((w) => w.word).join(', ');

    if (language == 'ja') {
      return '''
あなたは日本語教師です。以下の単語を使って、短い文章を書いてください。

単語: $wordList

要件:
- 100〜150字の短い文章
- 自然な日本語
- 3つの読解問題（4択）
- 各問題に解説付き

以下のJSON形式で回答してください（JSONのみ、他のテキストは不要）:
{
  "passage": "文章本文",
  "translation": "中国語翻訳",
  "questions": [
    {
      "question": "問題文",
      "options": ["選択肢A", "選択肢B", "選択肢C", "選択肢D"],
      "correct_index": 0,
      "explanation": "解説"
    }
  ]
}''';
    } else {
      return '''
You are an English teacher. Write a short passage using the following words.

Words: $wordList

Requirements:
- 150-200 words, B1-B2 difficulty level
- Natural, engaging English
- 4 comprehension questions (multiple choice, 4 options each)
- Each question has an explanation

Respond ONLY with valid JSON in this exact format:
{
  "passage": "The passage text here",
  "translation": "Chinese translation here",
  "questions": [
    {
      "question": "Question text?",
      "options": ["A", "B", "C", "D"],
      "correct_index": 0,
      "explanation": "Explanation why this is correct"
    }
  ]
}''';
    }
  }
}
