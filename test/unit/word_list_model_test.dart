import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/features/word_lists/domain/enums/language.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word_list.dart';

void main() {
  group('WordList', () {
    group('constructor defaults', () {
      test('has correct default values', () {
        final wl = WordList(name: 'Test', language: Language.en);
        expect(wl.id, isNull);
        expect(wl.type, WordListType.builtIn);
        expect(wl.wordCount, 0);
        expect(wl.iconName, isNull);
        expect(wl.learnedCount, 0);
        expect(wl.reviewDueCount, 0);
      });
    });

    group('toMap', () {
      test('converts fields to map correctly', () {
        final wl = WordList(
          id: 5,
          name: 'CEFR A2',
          language: Language.en,
          description: 'Elementary',
          type: WordListType.builtIn,
          wordCount: 100,
          iconName: 'book',
        );
        final map = wl.toMap();
        expect(map['id'], 5);
        expect(map['name'], 'CEFR A2');
        expect(map['language'], 'en');
        expect(map['description'], 'Elementary');
        expect(map['type'], 'built_in');
        expect(map['word_count'], 100);
        expect(map['icon_name'], 'book');
      });

      test('maps custom type correctly', () {
        final wl = WordList(
          name: 'My List',
          language: Language.ja,
          type: WordListType.custom,
        );
        expect(wl.toMap()['type'], 'custom');
      });

      test('maps Japanese language code correctly', () {
        final wl = WordList(name: 'JLPT N5', language: Language.ja);
        expect(wl.toMap()['language'], 'ja');
      });

      test('omits id when null', () {
        final wl = WordList(name: 'Test', language: Language.en);
        expect(wl.toMap().containsKey('id'), false);
      });
    });

    group('fromMap', () {
      test('parses all fields from map', () {
        final map = {
          'id': 10,
          'name': 'CET-4',
          'language': 'en',
          'description': 'College English Test',
          'type': 'built_in',
          'word_count': 500,
          'icon_name': 'star',
          'created_at': '2025-01-01T00:00:00.000',
          'updated_at': '2025-06-01T00:00:00.000',
          'learned_count': 50,
          'review_due_count': 10,
        };
        final wl = WordList.fromMap(map);
        expect(wl.id, 10);
        expect(wl.name, 'CET-4');
        expect(wl.language, Language.en);
        expect(wl.description, 'College English Test');
        expect(wl.type, WordListType.builtIn);
        expect(wl.wordCount, 500);
        expect(wl.iconName, 'star');
        expect(wl.createdAt, isNotNull);
        expect(wl.updatedAt, isNotNull);
        expect(wl.learnedCount, 50);
        expect(wl.reviewDueCount, 10);
      });

      test('parses custom type', () {
        final map = {
          'name': 'My Words',
          'language': 'en',
          'type': 'custom',
        };
        expect(WordList.fromMap(map).type, WordListType.custom);
      });

      test('defaults to builtIn for unknown type', () {
        final map = {
          'name': 'Test',
          'language': 'en',
          'type': 'unknown',
        };
        expect(WordList.fromMap(map).type, WordListType.builtIn);
      });

      test('handles missing optional fields', () {
        final map = {
          'name': 'Minimal',
          'language': 'ja',
        };
        final wl = WordList.fromMap(map);
        expect(wl.id, isNull);
        expect(wl.description, isNull);
        expect(wl.wordCount, 0);
        expect(wl.iconName, isNull);
        expect(wl.createdAt, isNull);
        expect(wl.learnedCount, 0);
        expect(wl.reviewDueCount, 0);
      });
    });

    group('progress', () {
      test('returns 0 when wordCount is 0', () {
        final wl = WordList(name: 'Empty', language: Language.en, wordCount: 0);
        expect(wl.progress, 0);
      });

      test('calculates progress correctly', () {
        final wl = WordList(
          name: 'Test',
          language: Language.en,
          wordCount: 100,
          learnedCount: 25,
        );
        expect(wl.progress, 0.25);
      });

      test('returns 1.0 when all words learned', () {
        final wl = WordList(
          name: 'Done',
          language: Language.en,
          wordCount: 50,
          learnedCount: 50,
        );
        expect(wl.progress, 1.0);
      });
    });

    group('isKanjiList', () {
      test('returns true for 漢字 in name', () {
        final wl = WordList(name: '小学漢字1年', language: Language.ja);
        expect(wl.isKanjiList, true);
      });

      test('returns true for 汉字 in name', () {
        final wl = WordList(name: '常用汉字', language: Language.ja);
        expect(wl.isKanjiList, true);
      });

      test('returns true for Kanji in name', () {
        final wl = WordList(name: 'School Kanji Grade 1', language: Language.ja);
        expect(wl.isKanjiList, true);
      });

      test('returns false for non-kanji list', () {
        final wl = WordList(name: 'JLPT N5', language: Language.ja);
        expect(wl.isKanjiList, false);
      });

      test('returns false for English list', () {
        final wl = WordList(name: 'CEFR A2', language: Language.en);
        expect(wl.isKanjiList, false);
      });
    });

    group('copyWith', () {
      test('copies with changed fields', () {
        final wl = WordList(
          name: 'Original',
          language: Language.en,
          wordCount: 10,
        );
        final copied = wl.copyWith(name: 'Changed', wordCount: 20);
        expect(copied.name, 'Changed');
        expect(copied.wordCount, 20);
        expect(copied.language, Language.en); // unchanged
      });
    });
  });

  group('Word', () {
    group('toMap/fromMap roundtrip', () {
      test('preserves English word data', () {
        final word = Word(
          id: 1,
          wordListId: 10,
          language: Language.en,
          word: 'apple',
          translationCn: '苹果',
          partOfSpeech: 'n.',
          difficultyLevel: 2,
          phonetic: '/ˈæp.əl/',
        );
        final restored = Word.fromMap(word.toMap());
        expect(restored.word, 'apple');
        expect(restored.translationCn, '苹果');
        expect(restored.partOfSpeech, 'n.');
        expect(restored.phonetic, '/ˈæp.əl/');
        expect(restored.language, Language.en);
      });

      test('preserves Japanese kanji data', () {
        final word = Word(
          id: 2,
          wordListId: 20,
          language: Language.ja,
          word: '山',
          translationCn: '山',
          reading: 'やま',
          onyomi: 'サン、ザン',
          kunyomi: 'やま',
        );
        final restored = Word.fromMap(word.toMap());
        expect(restored.word, '山');
        expect(restored.reading, 'やま');
        expect(restored.onyomi, 'サン、ザン');
        expect(restored.kunyomi, 'やま');
      });
    });

    group('isKanji', () {
      test('returns true when onyomi is present', () {
        final w = Word(
          wordListId: 1,
          language: Language.ja,
          word: '山',
          translationCn: '山',
          onyomi: 'サン',
        );
        expect(w.isKanji, true);
      });

      test('returns true when kunyomi is present', () {
        final w = Word(
          wordListId: 1,
          language: Language.ja,
          word: '山',
          translationCn: '山',
          kunyomi: 'やま',
        );
        expect(w.isKanji, true);
      });

      test('returns false when no readings', () {
        final w = Word(
          wordListId: 1,
          language: Language.en,
          word: 'test',
          translationCn: '测试',
        );
        expect(w.isKanji, false);
      });
    });

    group('allReadings', () {
      test('combines onyomi and kunyomi', () {
        final w = Word(
          wordListId: 1,
          language: Language.ja,
          word: '山',
          translationCn: '山',
          onyomi: 'サン、ザン',
          kunyomi: 'やま',
        );
        final readings = w.allReadings;
        expect(readings, contains('サン'));
        expect(readings, contains('ザン'));
        expect(readings, contains('やま'));
        expect(readings.length, 3);
      });

      test('returns empty list when no readings', () {
        final w = Word(
          wordListId: 1,
          language: Language.en,
          word: 'test',
          translationCn: '测试',
        );
        expect(w.allReadings, isEmpty);
      });

      test('handles comma-separated readings', () {
        final w = Word(
          wordListId: 1,
          language: Language.ja,
          word: '日',
          translationCn: '日',
          onyomi: 'ニチ,ジツ',
        );
        expect(w.allReadings, ['ニチ', 'ジツ']);
      });
    });

    group('displayReading', () {
      test('returns reading for Japanese word', () {
        final w = Word(
          wordListId: 1,
          language: Language.ja,
          word: '学校',
          translationCn: '学校',
          reading: 'がっこう',
        );
        expect(w.displayReading, 'がっこう');
      });

      test('returns phonetic for English word', () {
        final w = Word(
          wordListId: 1,
          language: Language.en,
          word: 'school',
          translationCn: '学校',
          phonetic: '/skuːl/',
        );
        expect(w.displayReading, '/skuːl/');
      });

      test('returns empty string when no reading info', () {
        final w = Word(
          wordListId: 1,
          language: Language.en,
          word: 'test',
          translationCn: '测试',
        );
        expect(w.displayReading, '');
      });
    });
  });

  group('ExampleSentence', () {
    test('toMap/fromMap roundtrip', () {
      final sentence = ExampleSentence(
        id: 1,
        wordId: 10,
        sentence: 'This is a test.',
        translationCn: '这是一个测试。',
        reading: 'テスト',
        sortOrder: 2,
      );
      final restored = ExampleSentence.fromMap(sentence.toMap());
      expect(restored.wordId, 10);
      expect(restored.sentence, 'This is a test.');
      expect(restored.translationCn, '这是一个测试。');
      expect(restored.reading, 'テスト');
      expect(restored.sortOrder, 2);
    });

    test('handles null reading', () {
      final sentence = ExampleSentence(
        wordId: 1,
        sentence: 'Hello',
        translationCn: '你好',
      );
      final map = sentence.toMap();
      expect(map['reading'], isNull);
      final restored = ExampleSentence.fromMap(map);
      expect(restored.reading, isNull);
    });
  });

  group('Language', () {
    test('fromCode returns correct language', () {
      expect(Language.fromCode('en'), Language.en);
      expect(Language.fromCode('ja'), Language.ja);
    });

    test('fromCode defaults to English for unknown code', () {
      expect(Language.fromCode('xx'), Language.en);
    });

    test('language codes are correct', () {
      expect(Language.en.code, 'en');
      expect(Language.ja.code, 'ja');
    });
  });
}
