import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'download_mirror.dart';

/// TTS model type
enum TtsModelType {
  /// VITS/Piper models
  vits,
  /// Kokoro multi-language model (supports Japanese)
  kokoro,
}

/// TTS model information
class TtsModel {
  final String id;
  final String name;
  final String language;
  final String url;
  final int sizeBytes;
  final TtsModelType modelType;
  /// Supported languages for this model
  final List<String> supportedLanguages;

  const TtsModel({
    required this.id,
    required this.name,
    required this.language,
    required this.url,
    required this.sizeBytes,
    this.modelType = TtsModelType.vits,
    this.supportedLanguages = const ['en'],
  });

  String get sizeDisplay {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get supportsJapanese => supportedLanguages.contains('ja');
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(int received, int total);

/// TTS Model Downloader - handles downloading and extracting TTS models
class TtsModelDownloader {
  /// Available TTS models.
  /// The [url] field stores the filename only; the base URL is resolved
  /// at download time via [DownloadMirror] based on the user's region setting.
  /// See: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/index.html
  static const List<TtsModel> availableModels = [
    // VITS/Piper models - English
    TtsModel(
      id: 'en-us-lessac',
      name: 'English (US) - Lessac',
      language: 'en',
      url: 'vits-piper-en_US-lessac-medium.tar.bz2',
      sizeBytes: 65 * 1024 * 1024, // ~65 MB
      supportedLanguages: ['en'],
    ),
    TtsModel(
      id: 'en-gb-alba',
      name: 'English (UK) - Alba',
      language: 'en',
      url: 'vits-piper-en_GB-alba-medium.tar.bz2',
      sizeBytes: 55 * 1024 * 1024, // ~55 MB
      supportedLanguages: ['en'],
    ),
    // VITS/Piper models - French
    TtsModel(
      id: 'fr-fr-siwis',
      name: 'French - Siwis (Female)',
      language: 'fr',
      url: 'vits-piper-fr_FR-siwis-medium.tar.bz2',
      sizeBytes: 65 * 1024 * 1024, // ~65 MB
      supportedLanguages: ['fr'],
    ),
    TtsModel(
      id: 'fr-fr-upmc',
      name: 'French - UPMC (Alternative)',
      language: 'fr',
      url: 'vits-piper-fr_FR-upmc-medium.tar.bz2',
      sizeBytes: 55 * 1024 * 1024, // ~55 MB
      supportedLanguages: ['fr'],
    ),
  ];

  /// Resolve the full download URL for a model.
  static String resolveUrl(TtsModel model, DownloadRegion region) {
    final base = DownloadMirror.ttsBaseUrl(region);
    return '$base/${model.url}';
  }

  final Dio _dio = Dio();

  /// Get the TTS models directory
  Future<String> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/tts_models';
  }

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(String modelId) async {
    try {
      final modelsDir = await getModelsDirectory();
      final modelDir = Directory('$modelsDir/$modelId');
      if (!modelDir.existsSync()) return false;

      // Check for any .onnx file (VITS models have names like en_GB-alba-medium.onnx)
      await for (final entity in modelDir.list()) {
        if (entity is File && entity.path.endsWith('.onnx')) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get the currently active model ID
  Future<String?> getActiveModelId() async {
    try {
      final modelsDir = await getModelsDirectory();
      final activeFile = File('$modelsDir/active_model.txt');
      if (activeFile.existsSync()) {
        return activeFile.readAsStringSync().trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Set the active model
  /// Note: TtsService now loads models directly from subdirectories,
  /// so we no longer copy files to the root directory.
  Future<void> setActiveModel(String modelId) async {
    try {
      final modelsDir = await getModelsDirectory();
      await Directory(modelsDir).create(recursive: true);
      final activeFile = File('$modelsDir/active_model.txt');
      await activeFile.writeAsString(modelId);
      debugPrint('TTS: Set active model to: $modelId');
    } catch (e) {
      debugPrint('Failed to set active model: $e');
    }
  }

  /// Download and extract a TTS model.
  /// [region] determines which mirror to use for the download URL.
  Future<void> downloadModel(
    TtsModel model, {
    DownloadProgressCallback? onProgress,
    VoidCallback? onExtracting,
    DownloadRegion region = DownloadRegion.international,
  }) async {
    final modelsDir = await getModelsDirectory();
    await Directory(modelsDir).create(recursive: true);

    final archivePath = '$modelsDir/${model.id}.tar.bz2';
    final downloadUrl = resolveUrl(model, region);

    try {
      // Download the archive
      debugPrint('TTS: Downloading ${model.name} from $downloadUrl');
      await _dio.download(
        downloadUrl,
        archivePath,
        onReceiveProgress: onProgress,
      );

      // Extract the archive
      debugPrint('TTS: Extracting ${model.name}...');
      onExtracting?.call();

      await _extractTarBz2(archivePath, modelsDir, model.id);

      // Clean up archive
      final archiveFile = File(archivePath);
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }

      debugPrint('TTS: ${model.name} installed successfully');
    } catch (e) {
      debugPrint('TTS: Download failed: $e');
      // Clean up on failure
      final archiveFile = File(archivePath);
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }
      rethrow;
    }
  }

  /// Extract tar.bz2 archive
  Future<void> _extractTarBz2(
      String archivePath, String destDir, String modelId) async {
    final bytes = await File(archivePath).readAsBytes();

    // Decompress bz2
    final decompressed = BZip2Decoder().decodeBytes(bytes);

    // Extract tar
    final archive = TarDecoder().decodeBytes(decompressed);

    final modelDir = Directory('$destDir/$modelId');
    await modelDir.create(recursive: true);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        // Remove the top-level directory from the path
        final parts = filename.split('/');
        final relativePath = parts.length > 1 ? parts.sublist(1).join('/') : filename;

        if (relativePath.isEmpty) continue;

        final outFile = File('$destDir/$modelId/$relativePath');
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
  }

  /// Delete a downloaded model
  Future<void> deleteModel(String modelId) async {
    try {
      final modelsDir = await getModelsDirectory();
      final modelDir = Directory('$modelsDir/$modelId');
      if (modelDir.existsSync()) {
        await modelDir.delete(recursive: true);
      }

      // If this was the active model, clear the active model
      final activeId = await getActiveModelId();
      if (activeId == modelId) {
        final activeFile = File('$modelsDir/active_model.txt');
        if (activeFile.existsSync()) {
          await activeFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Failed to delete model: $e');
    }
  }

  /// Get list of downloaded models
  Future<List<String>> getDownloadedModels() async {
    final downloaded = <String>[];
    for (final model in availableModels) {
      if (await isModelDownloaded(model.id)) {
        downloaded.add(model.id);
      }
    }
    return downloaded;
  }
}
