import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// TTS model information
class TtsModel {
  final String id;
  final String name;
  final String language;
  final String url;
  final int sizeBytes;

  const TtsModel({
    required this.id,
    required this.name,
    required this.language,
    required this.url,
    required this.sizeBytes,
  });

  String get sizeDisplay {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(int received, int total);

/// TTS Model Downloader - handles downloading and extracting TTS models
class TtsModelDownloader {
  static const String _baseUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';

  /// Available TTS models
  /// See: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/index.html
  static const List<TtsModel> availableModels = [
    TtsModel(
      id: 'en-us-amy',
      name: 'English (US) - Amy',
      language: 'en',
      url: '$_baseUrl/vits-piper-en_US-amy-medium.tar.bz2',
      sizeBytes: 65 * 1024 * 1024, // ~65 MB
    ),
    TtsModel(
      id: 'en-us-lessac',
      name: 'English (US) - Lessac',
      language: 'en',
      url: '$_baseUrl/vits-piper-en_US-lessac-medium.tar.bz2',
      sizeBytes: 65 * 1024 * 1024, // ~65 MB
    ),
    TtsModel(
      id: 'en-gb-alba',
      name: 'English (UK) - Alba',
      language: 'en',
      url: '$_baseUrl/vits-piper-en_GB-alba-medium.tar.bz2',
      sizeBytes: 55 * 1024 * 1024, // ~55 MB
    ),
    TtsModel(
      id: 'zh',
      name: 'Chinese + English',
      language: 'zh',
      url: '$_baseUrl/vits-melo-tts-zh_en.tar.bz2',
      sizeBytes: 150 * 1024 * 1024, // ~150 MB
    ),
  ];

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

      // Check for the model.onnx file
      final modelFile = File('$modelsDir/$modelId/model.onnx');
      return modelFile.existsSync();
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
  Future<void> setActiveModel(String modelId) async {
    try {
      final modelsDir = await getModelsDirectory();
      await Directory(modelsDir).create(recursive: true);
      final activeFile = File('$modelsDir/active_model.txt');
      await activeFile.writeAsString(modelId);

      // Copy model files to root for TtsService to find
      await _activateModel(modelId);
    } catch (e) {
      debugPrint('Failed to set active model: $e');
    }
  }

  /// Copy model files to the root models directory
  Future<void> _activateModel(String modelId) async {
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory('$modelsDir/$modelId');

    if (!modelDir.existsSync()) return;

    // Copy all files from model directory to root
    await for (final entity in modelDir.list()) {
      if (entity is File) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        final destFile = File('$modelsDir/$fileName');
        await entity.copy(destFile.path);
      } else if (entity is Directory) {
        final dirName = entity.path.split(Platform.pathSeparator).last;
        await _copyDirectory(entity, Directory('$modelsDir/$dirName'));
      }
    }
  }

  /// Copy a directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list()) {
      if (entity is File) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        await entity.copy('${destination.path}/$fileName');
      } else if (entity is Directory) {
        final dirName = entity.path.split(Platform.pathSeparator).last;
        await _copyDirectory(
            entity, Directory('${destination.path}/$dirName'));
      }
    }
  }

  /// Download and extract a TTS model
  Future<void> downloadModel(
    TtsModel model, {
    DownloadProgressCallback? onProgress,
    VoidCallback? onExtracting,
  }) async {
    final modelsDir = await getModelsDirectory();
    await Directory(modelsDir).create(recursive: true);

    final archivePath = '$modelsDir/${model.id}.tar.bz2';

    try {
      // Download the archive
      debugPrint('TTS: Downloading ${model.name}...');
      await _dio.download(
        model.url,
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
