import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/enums/language.dart';
import '../../domain/models/word.dart';
import '../../domain/models/word_list.dart';

/// Loads word list data from bundled JSON assets
class WordListAssetDatasource {
  static const _assetPaths = {
    // English - CET-4 (only built-in list; others available via download)
    'cet4': 'assets/wordlists/english/cet4.json',
  };

  /// Load all built-in word lists metadata (without words)
  Future<List<WordList>> loadBuiltInWordLists() async {
    final results = <WordList>[];

    for (final entry in _assetPaths.entries) {
      try {
        final jsonStr = await rootBundle.loadString(entry.value);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final words = data['words'] as List<dynamic>;

        results.add(WordList(
          name: data['name'] as String,
          language: Language.fromCode(data['language'] as String),
          description: data['description'] as String?,
          type: WordListType.builtIn,
          wordCount: words.length,
          iconName: data['icon_name'] as String?,
        ));
      } catch (e) {
        // Skip invalid asset files
        continue;
      }
    }

    return results;
  }

  /// Load a specific word list with all words and example sentences from JSON
  Future<({WordList wordList, List<Word> words})> loadWordListData(
      String assetKey) async {
    final path = _assetPaths[assetKey];
    if (path == null) {
      throw ArgumentError('Unknown asset key: $assetKey');
    }

    final jsonStr = await rootBundle.loadString(path);
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final language = Language.fromCode(data['language'] as String);
    final wordsJson = data['words'] as List<dynamic>;

    final wordList = WordList(
      name: data['name'] as String,
      language: language,
      description: data['description'] as String?,
      type: WordListType.builtIn,
      wordCount: wordsJson.length,
      iconName: data['icon_name'] as String?,
    );

    final words = wordsJson.map((w) {
      final wordMap = w as Map<String, dynamic>;
      final examplesJson = wordMap['examples'] as List<dynamic>? ?? [];

      // Parse examples - kanji examples have "word"+"reading", vocabulary has "sentence"
      final examples = examplesJson.map((e) {
        final exMap = e as Map<String, dynamic>;
        // For kanji: use "word" as sentence if "sentence" doesn't exist
        final sentence = exMap['sentence'] as String? ??
            exMap['word'] as String? ??
            '';
        return ExampleSentence(
          wordId: 0, // Will be set after DB insert
          sentence: sentence,
          translationCn: exMap['translation_cn'] as String? ?? '',
          reading: exMap['reading'] as String?, // For kanji compound words
        );
      }).toList();

      return Word(
        wordListId: 0, // Will be set after DB insert
        language: language,
        word: wordMap['word'] as String,
        translationCn: wordMap['translation_cn'] as String,
        partOfSpeech: wordMap['part_of_speech'] as String?,
        difficultyLevel: wordMap['difficulty_level'] as int? ?? 1,
        phonetic: wordMap['phonetic'] as String?,
        reading: wordMap['reading'] as String?,
        jlptLevel: wordMap['jlpt_level'] as String?,
        onyomi: wordMap['onyomi'] as String?,
        kunyomi: wordMap['kunyomi'] as String?,
        exampleSentences: examples,
      );
    }).toList();

    return (wordList: wordList, words: words);
  }

  /// Get all available asset keys
  static List<String> get availableAssetKeys => _assetPaths.keys.toList();
}
