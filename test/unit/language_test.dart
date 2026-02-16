import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/features/word_lists/domain/enums/language.dart';

void main() {
  group('Language enum', () {
    test('has correct codes', () {
      expect(Language.en.code, 'en');
      expect(Language.ja.code, 'ja');
      expect(Language.fr.code, 'fr');
    });

    test('has correct native names', () {
      expect(Language.en.nativeName, 'English');
      expect(Language.ja.nativeName, '日本語');
      expect(Language.fr.nativeName, 'Français');
    });

    test('has correct Chinese names', () {
      expect(Language.en.chineseName, '英语');
      expect(Language.ja.chineseName, '日语');
      expect(Language.fr.chineseName, '法语');
    });

    test('fromCode returns correct language', () {
      expect(Language.fromCode('en'), Language.en);
      expect(Language.fromCode('ja'), Language.ja);
      expect(Language.fromCode('fr'), Language.fr);
    });

    test('fromCode returns English for invalid code', () {
      expect(Language.fromCode('invalid'), Language.en);
      expect(Language.fromCode(''), Language.en);
      expect(Language.fromCode('es'), Language.en); // Spanish not supported yet
    });

    test('fromCode handles case sensitivity', () {
      // Should handle exact case match
      expect(Language.fromCode('fr'), Language.fr);
      // Invalid case should default to English
      expect(Language.fromCode('FR'), Language.en);
    });

    test('French language enum value exists', () {
      expect(Language.values.length, 3);
      expect(Language.values.contains(Language.fr), true);
    });

    test('all languages have unique codes', () {
      final codes = Language.values.map((l) => l.code).toSet();
      expect(codes.length, Language.values.length);
    });
  });
}
