import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/core/services/download_mirror.dart';

void main() {
  group('DownloadMirror', () {
    group('wordlistBaseUrl', () {
      test('returns GitHub URL for international', () {
        final url = DownloadMirror.wordlistBaseUrl(DownloadRegion.international);
        expect(url, contains('github'));
        expect(url, contains('wordmaster-wordlists'));
      });

      test('returns China mirror URL for china', () {
        final url = DownloadMirror.wordlistBaseUrl(DownloadRegion.china);
        expect(url, contains('47.93.144.50'));
        expect(url, contains('wordlists'));
      });

      test('international and china URLs are different', () {
        final intl = DownloadMirror.wordlistBaseUrl(DownloadRegion.international);
        final china = DownloadMirror.wordlistBaseUrl(DownloadRegion.china);
        expect(intl, isNot(equals(china)));
      });
    });

    group('ttsBaseUrl', () {
      test('returns GitHub URL for international', () {
        final url = DownloadMirror.ttsBaseUrl(DownloadRegion.international);
        expect(url, contains('github'));
        expect(url, contains('tts-models'));
      });

      test('returns China mirror URL for china', () {
        final url = DownloadMirror.ttsBaseUrl(DownloadRegion.china);
        expect(url, contains('47.93.144.50'));
        expect(url, contains('tts-models'));
      });

      test('international and china URLs are different', () {
        final intl = DownloadMirror.ttsBaseUrl(DownloadRegion.international);
        final china = DownloadMirror.ttsBaseUrl(DownloadRegion.china);
        expect(intl, isNot(equals(china)));
      });
    });

    group('parseRegion', () {
      test('parses "china" to DownloadRegion.china', () {
        expect(DownloadMirror.parseRegion('china'), DownloadRegion.china);
      });

      test('parses "international" to DownloadRegion.international', () {
        expect(
          DownloadMirror.parseRegion('international'),
          DownloadRegion.international,
        );
      });

      test('parses null to international (default)', () {
        expect(DownloadMirror.parseRegion(null), DownloadRegion.international);
      });

      test('parses empty string to international (default)', () {
        expect(DownloadMirror.parseRegion(''), DownloadRegion.international);
      });

      test('parses unknown string to international (default)', () {
        expect(
          DownloadMirror.parseRegion('europe'),
          DownloadRegion.international,
        );
      });
    });

    group('regionToString', () {
      test('converts international to "international"', () {
        expect(
          DownloadMirror.regionToString(DownloadRegion.international),
          'international',
        );
      });

      test('converts china to "china"', () {
        expect(
          DownloadMirror.regionToString(DownloadRegion.china),
          'china',
        );
      });
    });

    group('parseRegion/regionToString roundtrip', () {
      test('international roundtrips', () {
        final str = DownloadMirror.regionToString(DownloadRegion.international);
        expect(DownloadMirror.parseRegion(str), DownloadRegion.international);
      });

      test('china roundtrips', () {
        final str = DownloadMirror.regionToString(DownloadRegion.china);
        expect(DownloadMirror.parseRegion(str), DownloadRegion.china);
      });
    });
  });
}
