import '../enums/language.dart';

enum WordListType { builtIn, custom }

class WordList {
  final int? id;
  final String name;
  final Language language;
  final String? description;
  final WordListType type;
  final int wordCount;
  final String? iconName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Transient fields (not stored in DB directly)
  final int learnedCount;
  final int reviewDueCount;

  const WordList({
    this.id,
    required this.name,
    required this.language,
    this.description,
    this.type = WordListType.builtIn,
    this.wordCount = 0,
    this.iconName,
    this.createdAt,
    this.updatedAt,
    this.learnedCount = 0,
    this.reviewDueCount = 0,
  });

  WordList copyWith({
    int? id,
    String? name,
    Language? language,
    String? description,
    WordListType? type,
    int? wordCount,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? learnedCount,
    int? reviewDueCount,
  }) {
    return WordList(
      id: id ?? this.id,
      name: name ?? this.name,
      language: language ?? this.language,
      description: description ?? this.description,
      type: type ?? this.type,
      wordCount: wordCount ?? this.wordCount,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      learnedCount: learnedCount ?? this.learnedCount,
      reviewDueCount: reviewDueCount ?? this.reviewDueCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'language': language.code,
      'description': description,
      'type': type == WordListType.builtIn ? 'built_in' : 'custom',
      'word_count': wordCount,
      'icon_name': iconName,
    };
  }

  factory WordList.fromMap(Map<String, dynamic> map) {
    return WordList(
      id: map['id'] as int?,
      name: map['name'] as String,
      language: Language.fromCode(map['language'] as String),
      description: map['description'] as String?,
      type: map['type'] == 'custom' ? WordListType.custom : WordListType.builtIn,
      wordCount: map['word_count'] as int? ?? 0,
      iconName: map['icon_name'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      learnedCount: map['learned_count'] as int? ?? 0,
      reviewDueCount: map['review_due_count'] as int? ?? 0,
    );
  }

  double get progress => wordCount > 0 ? learnedCount / wordCount : 0;

  /// Check if this word list is a kanji list (contains kanji reading info)
  bool get isKanjiList =>
      name.contains('漢字') ||
      name.contains('汉字') ||
      name.contains('Kanji');
}
