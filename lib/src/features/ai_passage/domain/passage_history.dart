/// History entry for a generated passage
class PassageHistory {
  final int id;
  final DateTime generationDate;
  final String language;
  final String passagePreview;
  final int? score;
  final int totalQuestions;
  final bool isCompleted;

  const PassageHistory({
    required this.id,
    required this.generationDate,
    required this.language,
    required this.passagePreview,
    this.score,
    required this.totalQuestions,
    required this.isCompleted,
  });

  /// Score percentage (0-100)
  int? get scorePercentage {
    if (score == null || totalQuestions == 0) return null;
    return (score! / totalQuestions * 100).round();
  }

  /// Display string for score
  String get scoreDisplay {
    if (!isCompleted) return '未完成';
    if (score == null) return '未评分';
    return '$score/$totalQuestions ($scorePercentage%)';
  }

  /// Language display name
  String get languageDisplay {
    return language == 'en' ? 'English' : '日本語';
  }
}
