import '../enums/language.dart';

class ExampleSentence {
  final int? id;
  final int wordId;
  final String sentence;
  final String translationCn;
  final int sortOrder;

  const ExampleSentence({
    this.id,
    required this.wordId,
    required this.sentence,
    required this.translationCn,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word_id': wordId,
      'sentence': sentence,
      'translation_cn': translationCn,
      'sort_order': sortOrder,
    };
  }

  factory ExampleSentence.fromMap(Map<String, dynamic> map) {
    return ExampleSentence(
      id: map['id'] as int?,
      wordId: map['word_id'] as int,
      sentence: map['sentence'] as String,
      translationCn: map['translation_cn'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

class Word {
  final int? id;
  final int wordListId;
  final Language language;

  // Common fields
  final String word;
  final String translationCn;
  final String? partOfSpeech;
  final int difficultyLevel;

  // English-specific
  final String? phonetic;
  final String? audioUrl;

  // Japanese-specific
  final String? reading;
  final String? jlptLevel;

  // Populated via join
  final List<ExampleSentence> exampleSentences;

  const Word({
    this.id,
    required this.wordListId,
    required this.language,
    required this.word,
    required this.translationCn,
    this.partOfSpeech,
    this.difficultyLevel = 1,
    this.phonetic,
    this.audioUrl,
    this.reading,
    this.jlptLevel,
    this.exampleSentences = const [],
  });

  Word copyWith({
    int? id,
    int? wordListId,
    Language? language,
    String? word,
    String? translationCn,
    String? partOfSpeech,
    int? difficultyLevel,
    String? phonetic,
    String? audioUrl,
    String? reading,
    String? jlptLevel,
    List<ExampleSentence>? exampleSentences,
  }) {
    return Word(
      id: id ?? this.id,
      wordListId: wordListId ?? this.wordListId,
      language: language ?? this.language,
      word: word ?? this.word,
      translationCn: translationCn ?? this.translationCn,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      phonetic: phonetic ?? this.phonetic,
      audioUrl: audioUrl ?? this.audioUrl,
      reading: reading ?? this.reading,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      exampleSentences: exampleSentences ?? this.exampleSentences,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word_list_id': wordListId,
      'language': language.code,
      'word': word,
      'translation_cn': translationCn,
      'part_of_speech': partOfSpeech,
      'difficulty_level': difficultyLevel,
      'phonetic': phonetic,
      'audio_url': audioUrl,
      'reading': reading,
      'jlpt_level': jlptLevel,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      wordListId: map['word_list_id'] as int,
      language: Language.fromCode(map['language'] as String),
      word: map['word'] as String,
      translationCn: map['translation_cn'] as String,
      partOfSpeech: map['part_of_speech'] as String?,
      difficultyLevel: map['difficulty_level'] as int? ?? 1,
      phonetic: map['phonetic'] as String?,
      audioUrl: map['audio_url'] as String?,
      reading: map['reading'] as String?,
      jlptLevel: map['jlpt_level'] as String?,
    );
  }

  /// Display text for the word with pronunciation info
  String get displayReading {
    if (language == Language.ja && reading != null) {
      return reading!;
    }
    if (language == Language.en && phonetic != null) {
      return phonetic!;
    }
    return '';
  }
}
