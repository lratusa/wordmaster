class UserProgress {
  final int? id;
  final int wordId;
  final String fsrsCardJson;
  final DateTime dueDate;
  final double stability;
  final double difficulty;
  final int state;
  final int reps;
  final int lapses;
  final int reviewCount;
  final int correctCount;
  final DateTime? lastReviewedAt;
  final bool isStarred;
  final bool isNew;
  final int masteryLevel;
  final String? lastQuizType;

  const UserProgress({
    this.id,
    required this.wordId,
    required this.fsrsCardJson,
    required this.dueDate,
    this.stability = 0,
    this.difficulty = 0,
    this.state = 0,
    this.reps = 0,
    this.lapses = 0,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.lastReviewedAt,
    this.isStarred = false,
    this.isNew = true,
    this.masteryLevel = 0,
    this.lastQuizType,
  });

  UserProgress copyWith({
    int? id,
    int? wordId,
    String? fsrsCardJson,
    DateTime? dueDate,
    double? stability,
    double? difficulty,
    int? state,
    int? reps,
    int? lapses,
    int? reviewCount,
    int? correctCount,
    DateTime? lastReviewedAt,
    bool? isStarred,
    bool? isNew,
    int? masteryLevel,
    String? lastQuizType,
  }) {
    return UserProgress(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      fsrsCardJson: fsrsCardJson ?? this.fsrsCardJson,
      dueDate: dueDate ?? this.dueDate,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      state: state ?? this.state,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      reviewCount: reviewCount ?? this.reviewCount,
      correctCount: correctCount ?? this.correctCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      isStarred: isStarred ?? this.isStarred,
      isNew: isNew ?? this.isNew,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      lastQuizType: lastQuizType ?? this.lastQuizType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word_id': wordId,
      'fsrs_card_json': fsrsCardJson,
      'due_date': dueDate.toUtc().toIso8601String(),
      'stability': stability,
      'difficulty': difficulty,
      'state': state,
      'reps': reps,
      'lapses': lapses,
      'review_count': reviewCount,
      'correct_count': correctCount,
      'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
      'is_starred': isStarred ? 1 : 0,
      'is_new': isNew ? 1 : 0,
      'mastery_level': masteryLevel,
      'last_quiz_type': lastQuizType,
    };
  }

  factory UserProgress.fromMap(Map<String, dynamic> map) {
    return UserProgress(
      id: map['id'] as int?,
      wordId: map['word_id'] as int,
      fsrsCardJson: map['fsrs_card_json'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      stability: (map['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0,
      state: map['state'] as int? ?? 0,
      reps: map['reps'] as int? ?? 0,
      lapses: map['lapses'] as int? ?? 0,
      reviewCount: map['review_count'] as int? ?? 0,
      correctCount: map['correct_count'] as int? ?? 0,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.tryParse(map['last_reviewed_at'] as String)
          : null,
      isStarred: (map['is_starred'] as int? ?? 0) == 1,
      isNew: (map['is_new'] as int? ?? 1) == 1,
      masteryLevel: map['mastery_level'] as int? ?? 0,
      lastQuizType: map['last_quiz_type'] as String?,
    );
  }
}
