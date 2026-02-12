import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/features/word_lists/domain/enums/language.dart';
import 'package:wordmaster/src/features/word_lists/domain/models/word.dart';

void main() {
  group('Language', () {
    test('fromCode returns correct language for "en"', () {
      expect(Language.fromCode('en'), equals(Language.en));
    });

    test('fromCode returns correct language for "ja"', () {
      expect(Language.fromCode('ja'), equals(Language.ja));
    });

    test('fromCode defaults to English for unknown code', () {
      expect(Language.fromCode('unknown'), equals(Language.en));
    });

    test('English language has correct properties', () {
      expect(Language.en.code, equals('en'));
      expect(Language.en.nativeName, equals('English'));
      expect(Language.en.chineseName, equals('英语'));
    });

    test('Japanese language has correct properties', () {
      expect(Language.ja.code, equals('ja'));
      expect(Language.ja.nativeName, equals('日本語'));
      expect(Language.ja.chineseName, equals('日语'));
    });
  });

  group('Word', () {
    test('creates English word with required fields', () {
      final word = Word(
        wordListId: 1,
        language: Language.en,
        word: 'hello',
        translationCn: '你好',
      );

      expect(word.word, equals('hello'));
      expect(word.language, equals(Language.en));
      expect(word.translationCn, equals('你好'));
      expect(word.difficultyLevel, equals(1));
    });

    test('creates Japanese word with reading', () {
      final word = Word(
        wordListId: 1,
        language: Language.ja,
        word: '食べる',
        translationCn: '吃',
        reading: 'たべる',
        jlptLevel: 'N5',
      );

      expect(word.word, equals('食べる'));
      expect(word.reading, equals('たべる'));
      expect(word.jlptLevel, equals('N5'));
    });

    group('displayReading', () {
      test('returns reading for Japanese word', () {
        final word = Word(
          wordListId: 1,
          language: Language.ja,
          word: '食べる',
          translationCn: '吃',
          reading: 'たべる',
        );

        expect(word.displayReading, equals('たべる'));
      });

      test('returns phonetic for English word', () {
        final word = Word(
          wordListId: 1,
          language: Language.en,
          word: 'hello',
          translationCn: '你好',
          phonetic: '/həˈloʊ/',
        );

        expect(word.displayReading, equals('/həˈloʊ/'));
      });

      test('returns empty string when no reading info', () {
        final word = Word(
          wordListId: 1,
          language: Language.en,
          word: 'test',
          translationCn: '测试',
        );

        expect(word.displayReading, equals(''));
      });
    });

    group('toMap / fromMap', () {
      test('serialization is symmetric for English word', () {
        final original = Word(
          id: 42,
          wordListId: 1,
          language: Language.en,
          word: 'abandon',
          translationCn: '放弃',
          phonetic: '/əˈbændən/',
          partOfSpeech: 'verb',
          difficultyLevel: 2,
        );

        final map = original.toMap();
        final restored = Word.fromMap({...map, 'id': 42});

        expect(restored.id, equals(42));
        expect(restored.word, equals('abandon'));
        expect(restored.phonetic, equals('/əˈbændən/'));
        expect(restored.language, equals(Language.en));
      });

      test('serialization is symmetric for Japanese word', () {
        final original = Word(
          id: 100,
          wordListId: 2,
          language: Language.ja,
          word: '勉強',
          translationCn: '学习',
          reading: 'べんきょう',
          jlptLevel: 'N5',
          difficultyLevel: 1,
        );

        final map = original.toMap();
        final restored = Word.fromMap({...map, 'id': 100});

        expect(restored.id, equals(100));
        expect(restored.word, equals('勉強'));
        expect(restored.reading, equals('べんきょう'));
        expect(restored.jlptLevel, equals('N5'));
      });
    });

    group('copyWith', () {
      test('copies word with new values', () {
        final original = Word(
          wordListId: 1,
          language: Language.en,
          word: 'hello',
          translationCn: '你好',
        );

        final copied = original.copyWith(
          word: 'goodbye',
          translationCn: '再见',
        );

        expect(copied.word, equals('goodbye'));
        expect(copied.translationCn, equals('再见'));
        expect(copied.language, equals(Language.en));
        expect(copied.wordListId, equals(1));
      });

      test('keeps original values when not specified', () {
        final original = Word(
          wordListId: 5,
          language: Language.ja,
          word: 'test',
          translationCn: '测试',
          reading: 'てすと',
        );

        final copied = original.copyWith(word: 'new');

        expect(copied.wordListId, equals(5));
        expect(copied.language, equals(Language.ja));
        expect(copied.reading, equals('てすと'));
      });
    });
  });

  group('ExampleSentence', () {
    test('creates example sentence with required fields', () {
      final sentence = ExampleSentence(
        wordId: 1,
        sentence: 'Hello, world!',
        translationCn: '你好，世界！',
      );

      expect(sentence.sentence, equals('Hello, world!'));
      expect(sentence.translationCn, equals('你好，世界！'));
      expect(sentence.sortOrder, equals(0));
    });

    test('toMap / fromMap are symmetric', () {
      final original = ExampleSentence(
        id: 10,
        wordId: 1,
        sentence: 'I will abandon this plan.',
        translationCn: '我将放弃这个计划。',
        sortOrder: 1,
      );

      final map = original.toMap();
      final restored = ExampleSentence.fromMap({...map, 'id': 10});

      expect(restored.id, equals(10));
      expect(restored.sentence, equals(original.sentence));
      expect(restored.sortOrder, equals(1));
    });
  });
}
