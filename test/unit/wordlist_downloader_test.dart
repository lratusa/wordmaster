import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/core/services/download_mirror.dart';
import 'package:wordmaster/src/core/services/wordlist_downloader.dart';

void main() {
  group('WordListDownloader - French packages', () {
    test('has French CEFR packages (A1-C2)', () {
      final frenchCefr = WordListDownloader.availablePackages
          .where((p) => p.language == 'fr' && p.category == WordListCategory.cefr)
          .toList();
      expect(frenchCefr.length, 6);

      final levels = frenchCefr.map((p) => p.level).toList();
      expect(levels, containsAll(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']));
    });

    test('has French DELF/DALF packages (A1-C2)', () {
      final delf = WordListDownloader.availablePackages
          .where((p) => p.language == 'fr' && p.category == WordListCategory.delf)
          .toList();
      expect(delf.length, 6);

      final levels = delf.map((p) => p.level).toList();
      expect(levels, containsAll(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']));
    });

    test('French CEFR packages have correct URL paths', () {
      final frenchCefr = WordListDownloader.availablePackages
          .where((p) => p.id.startsWith('cefr-fr'));
      for (final pkg in frenchCefr) {
        expect(pkg.url, startsWith('french/'));
        expect(pkg.url, endsWith('.json'));
      }
    });

    test('French DELF/DALF packages have correct URL paths', () {
      final delf = WordListDownloader.availablePackages
          .where((p) => p.category == WordListCategory.delf);
      for (final pkg in delf) {
        expect(pkg.url, startsWith('french/'));
        expect(pkg.url, endsWith('.json'));
      }
    });

    test('French packages have positive word counts', () {
      final frenchPkgs = WordListDownloader.availablePackages
          .where((p) => p.language == 'fr');
      for (final pkg in frenchPkgs) {
        expect(pkg.wordCount, greaterThan(0));
      }
    });

    test('French package word counts increase with level', () {
      final frenchCefr = WordListDownloader.availablePackages
          .where((p) => p.id.startsWith('cefr-fr'))
          .toList();
      // Sort by level
      final levelOrder = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
      frenchCefr.sort(
          (a, b) => levelOrder.indexOf(a.level) - levelOrder.indexOf(b.level));

      for (int i = 1; i < frenchCefr.length; i++) {
        expect(
          frenchCefr[i].wordCount,
          greaterThanOrEqualTo(frenchCefr[i - 1].wordCount),
          reason:
              '${frenchCefr[i].level} should have >= words than ${frenchCefr[i - 1].level}',
        );
      }
    });

    test('total French packages is 12', () {
      final frenchPkgs = WordListDownloader.availablePackages
          .where((p) => p.language == 'fr')
          .toList();
      expect(frenchPkgs.length, 12);
    });
  });

  group('WordListDownloader - French categories', () {
    test('frenchCategories includes CEFR and DELF', () {
      final cats = WordListDownloader.frenchCategories;
      expect(cats, contains(WordListCategory.cefr));
      expect(cats, contains(WordListCategory.delf));
      expect(cats.length, 2);
    });

    test('getCategoryName returns correct name for DELF', () {
      expect(
        WordListDownloader.getCategoryName(WordListCategory.delf),
        'DELF/DALF',
      );
    });

    test('getCategoryIcon returns correct icon for DELF', () {
      expect(
        WordListDownloader.getCategoryIcon(WordListCategory.delf),
        'workspace_premium',
      );
    });
  });

  group('WordListDownloader - getPackagesByLanguage', () {
    test('returns only French packages for "fr"', () {
      final pkgs = WordListDownloader.getPackagesByLanguage('fr');
      expect(pkgs.length, 12);
      for (final pkg in pkgs) {
        expect(pkg.language, 'fr');
      }
    });

    test('returns no French packages in English results', () {
      final pkgs = WordListDownloader.getPackagesByLanguage('en');
      for (final pkg in pkgs) {
        expect(pkg.language, isNot('fr'));
      }
    });
  });

  group('WordListDownloader - getPackagesByCategory', () {
    test('CEFR category includes both English and French', () {
      final pkgs =
          WordListDownloader.getPackagesByCategory(WordListCategory.cefr);
      final languages = pkgs.map((p) => p.language).toSet();
      expect(languages, containsAll(['en', 'fr']));
    });

    test('DELF category only includes French', () {
      final pkgs =
          WordListDownloader.getPackagesByCategory(WordListCategory.delf);
      for (final pkg in pkgs) {
        expect(pkg.language, 'fr');
      }
    });
  });

  group('WordListDownloader - resolveUrl', () {
    test('resolves French package URL for international region', () {
      final pkg = WordListDownloader.availablePackages
          .firstWhere((p) => p.id == 'cefr-fr-a1');
      final url =
          WordListDownloader.resolveUrl(pkg, DownloadRegion.international);
      expect(url, contains('github'));
      expect(url, endsWith('french/cefr_a1.json'));
    });

    test('resolves French package URL for China region', () {
      final pkg = WordListDownloader.availablePackages
          .firstWhere((p) => p.id == 'cefr-fr-a1');
      final url = WordListDownloader.resolveUrl(pkg, DownloadRegion.china);
      expect(url, contains('47.93.144.50'));
      expect(url, endsWith('french/cefr_a1.json'));
    });
  });

  group('WordListDownloader - data integrity', () {
    test('all package IDs are unique', () {
      final ids =
          WordListDownloader.availablePackages.map((p) => p.id).toSet();
      expect(ids.length, WordListDownloader.availablePackages.length);
    });

    test('all package URLs are relative paths (no http)', () {
      for (final pkg in WordListDownloader.availablePackages) {
        expect(pkg.url, isNot(startsWith('http')));
        expect(pkg.url, endsWith('.json'));
      }
    });

    test('all languages are valid codes', () {
      final validCodes = {'en', 'ja', 'fr'};
      for (final pkg in WordListDownloader.availablePackages) {
        expect(validCodes, contains(pkg.language),
            reason: '${pkg.id} has invalid language: ${pkg.language}');
      }
    });
  });
}
