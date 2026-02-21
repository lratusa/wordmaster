import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/core/services/download_mirror.dart';
import 'package:wordmaster/src/core/services/tts_model_downloader.dart';

void main() {
  group('TtsModel', () {
    test('sizeDisplay formats MB correctly', () {
      const model = TtsModel(
        id: 'test',
        name: 'Test',
        language: 'en',
        url: 'test.tar.bz2',
        sizeBytes: 65 * 1024 * 1024,
      );
      expect(model.sizeDisplay, '65.0 MB');
    });

    test('sizeDisplay formats KB correctly', () {
      const model = TtsModel(
        id: 'test',
        name: 'Test',
        language: 'en',
        url: 'test.tar.bz2',
        sizeBytes: 512 * 1024,
      );
      expect(model.sizeDisplay, '512.0 KB');
    });

    test('supportsJapanese returns true for Japanese models', () {
      const model = TtsModel(
        id: 'test',
        name: 'Test',
        language: 'ja',
        url: 'test.tar.bz2',
        sizeBytes: 100,
        supportedLanguages: ['ja'],
      );
      expect(model.supportsJapanese, true);
    });

    test('supportsJapanese returns false for non-Japanese models', () {
      const model = TtsModel(
        id: 'test',
        name: 'Test',
        language: 'en',
        url: 'test.tar.bz2',
        sizeBytes: 100,
        supportedLanguages: ['en'],
      );
      expect(model.supportsJapanese, false);
    });
  });

  group('TtsModelDownloader - Kokoro model configuration', () {
    test('Kokoro model is available in model list', () {
      final kokoro = TtsModelDownloader.availableModels
          .where((m) => m.id == 'kokoro-multi-lang')
          .toList();
      expect(kokoro.length, 1);
    });

    test('Kokoro model has correct type and language support', () {
      final kokoro = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'kokoro-multi-lang');
      expect(kokoro.modelType, TtsModelType.kokoro);
      expect(kokoro.supportedLanguages, containsAll(['en', 'ja', 'zh']));
      expect(kokoro.supportsJapanese, true);
      expect(kokoro.url, 'kokoro-multi-lang-v1_0.tar.bz2');
    });

    test('Kokoro model size is approximately 350MB', () {
      final kokoro = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'kokoro-multi-lang');
      expect(kokoro.sizeBytes, greaterThan(300 * 1024 * 1024));
      expect(kokoro.sizeBytes, lessThan(400 * 1024 * 1024));
    });

    test('only Kokoro model supports Japanese', () {
      final jaModels = TtsModelDownloader.availableModels
          .where((m) => m.supportsJapanese)
          .toList();
      expect(jaModels.length, 1);
      expect(jaModels.first.id, 'kokoro-multi-lang');
    });
  });

  group('TtsModelDownloader - French model configuration', () {
    test('has French TTS models available', () {
      final frenchModels = TtsModelDownloader.availableModels
          .where((m) => m.language == 'fr')
          .toList();
      expect(frenchModels.length, 2);
    });

    test('French Siwis model has correct configuration', () {
      final siwis = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'fr-fr-siwis');
      expect(siwis.language, 'fr');
      expect(siwis.name, contains('Siwis'));
      expect(siwis.url, 'vits-piper-fr_FR-siwis-medium.tar.bz2');
      expect(siwis.supportedLanguages, ['fr']);
      expect(siwis.modelType, TtsModelType.vits);
      expect(siwis.sizeBytes, 65 * 1024 * 1024);
    });

    test('French UPMC model has correct configuration', () {
      final upmc = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'fr-fr-upmc');
      expect(upmc.language, 'fr');
      expect(upmc.name, contains('UPMC'));
      expect(upmc.url, 'vits-piper-fr_FR-upmc-medium.tar.bz2');
      expect(upmc.supportedLanguages, ['fr']);
      expect(upmc.modelType, TtsModelType.vits);
      expect(upmc.sizeBytes, 55 * 1024 * 1024);
    });

    test('French models do not claim Japanese support', () {
      final frenchModels = TtsModelDownloader.availableModels
          .where((m) => m.language == 'fr');
      for (final model in frenchModels) {
        expect(model.supportsJapanese, false);
      }
    });

    test('all model IDs are unique', () {
      final ids = TtsModelDownloader.availableModels.map((m) => m.id).toSet();
      expect(ids.length, TtsModelDownloader.availableModels.length);
    });

    test('all model URLs are non-empty filenames', () {
      for (final model in TtsModelDownloader.availableModels) {
        expect(model.url, isNotEmpty);
        expect(model.url, endsWith('.tar.bz2'));
        // URL should be a filename only (no path separators)
        expect(model.url.contains('/'), false);
      }
    });
  });

  group('TtsModelDownloader - resolveUrl', () {
    test('resolves French model URL for international region', () {
      final model = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'fr-fr-siwis');
      final url =
          TtsModelDownloader.resolveUrl(model, DownloadRegion.international);
      expect(url, contains('github'));
      expect(url, endsWith('vits-piper-fr_FR-siwis-medium.tar.bz2'));
    });

    test('resolves French model URL for China region', () {
      final model = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'fr-fr-siwis');
      final url =
          TtsModelDownloader.resolveUrl(model, DownloadRegion.china);
      expect(url, contains('47.93.144.50'));
      expect(url, endsWith('vits-piper-fr_FR-siwis-medium.tar.bz2'));
    });

    test('international and China URLs differ only in base', () {
      final model = TtsModelDownloader.availableModels
          .firstWhere((m) => m.id == 'fr-fr-upmc');
      final intl =
          TtsModelDownloader.resolveUrl(model, DownloadRegion.international);
      final china =
          TtsModelDownloader.resolveUrl(model, DownloadRegion.china);
      expect(intl, isNot(equals(china)));
      // Both end with the same filename
      expect(intl.split('/').last, china.split('/').last);
    });
  });
}
