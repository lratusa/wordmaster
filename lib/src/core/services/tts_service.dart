import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// Text-to-speech service using sherpa-onnx for offline TTS.
/// Supports English and Japanese with high-quality neural voices.
class TtsService {
  sherpa_onnx.OfflineTts? _tts;
  AudioPlayer? _player;
  bool _isInitialized = false;
  bool _initFailed = false;
  String _modelDir = '';
  double _speed = 1.0;

  /// Check if TTS is supported on current platform
  bool get isSupported => Platform.isWindows || Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS;

  /// Check if TTS is ready
  bool get isReady => _isInitialized && _tts != null;

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_isInitialized || _initFailed) return;

    try {
      debugPrint('TTS: Initializing sherpa-onnx...');

      // Initialize sherpa-onnx bindings
      sherpa_onnx.initBindings();

      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      _modelDir = '${appDir.path}/tts_models';

      // Check if models are already extracted
      final modelDirExists = await Directory(_modelDir).exists();
      if (!modelDirExists) {
        debugPrint('TTS: Models not found. Please download models first.');
        debugPrint('TTS: Run: flutter pub run sherpa_onnx:download_models');
        // For now, we'll mark as failed and the app will work without TTS
        _initFailed = true;
        return;
      }

      // Create TTS instance with VITS model (English)
      // You can switch models by changing the configuration
      final config = _createTtsConfig();
      if (config == null) {
        debugPrint('TTS: Failed to create config');
        _initFailed = true;
        return;
      }

      _tts = sherpa_onnx.OfflineTts(config);
      _player = AudioPlayer();

      _isInitialized = true;
      debugPrint('TTS: Initialized successfully');
    } catch (e, stack) {
      debugPrint('TTS initialization failed: $e');
      debugPrint('Stack: $stack');
      _initFailed = true;
    }
  }

  /// Create TTS configuration based on available models
  sherpa_onnx.OfflineTtsConfig? _createTtsConfig() {
    try {
      // Try to find a VITS model in the model directory
      final modelPath = '$_modelDir/model.onnx';
      final tokensPath = '$_modelDir/tokens.txt';

      if (!File(modelPath).existsSync()) {
        debugPrint('TTS: Model file not found at $modelPath');
        return null;
      }

      final vitsConfig = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: modelPath,
        tokens: tokensPath,
        lexicon: '',
        dataDir: '$_modelDir/espeak-ng-data',
      );

      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        vits: vitsConfig,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      return sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      );
    } catch (e) {
      debugPrint('TTS: Failed to create config: $e');
      return null;
    }
  }

  /// Speak the given text in the specified language.
  /// [language] should be 'en' or 'ja'.
  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) return;

    try {
      // Try to initialize if not already done
      if (!_isInitialized && !_initFailed) {
        await initialize();
      }

      if (_tts == null || _initFailed) {
        debugPrint('TTS: Not available, skipping speech');
        return;
      }

      // Generate audio
      debugPrint('TTS: Generating speech for: ${text.substring(0, text.length.clamp(0, 50))}...');
      final audio = _tts!.generate(text: text, sid: 0, speed: _speed);

      if (audio.samples.isEmpty) {
        debugPrint('TTS: No audio generated');
        return;
      }

      // Write to temporary file
      final tempDir = await getTemporaryDirectory();
      final wavPath = '${tempDir.path}/tts_output.wav';
      sherpa_onnx.writeWave(
        filename: wavPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );

      // Play the audio
      await _player?.stop();
      await _player?.play(DeviceFileSource(wavPath));

      debugPrint('TTS: Playing audio (${audio.samples.length} samples)');
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// Set the speech rate (0.5 to 2.0).
  Future<void> setSpeechRate(double rate) async {
    _speed = rate.clamp(0.5, 2.0);
  }

  /// Check if a language is available.
  Future<bool> isLanguageAvailable(String language) async {
    // Sherpa-onnx model support depends on which model is loaded
    // For now, return true if TTS is initialized
    return _isInitialized && !_initFailed;
  }

  void dispose() {
    try {
      _player?.dispose();
      _tts?.free();
    } catch (e) {
      debugPrint('TTS dispose failed: $e');
    }
  }
}

/// Helper class to download and manage TTS models
class TtsModelManager {
  static const String _modelsBaseUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';

  /// Available models for download
  static const Map<String, String> availableModels = {
    'en-us': 'vits-piper-en_US-libritts_r-medium.tar.bz2',
    'en-gb': 'vits-piper-en_GB-cori-medium.tar.bz2',
    'ja': 'vits-piper-ja_JP-tohoku-medium.tar.bz2',
    'zh': 'vits-melo-tts-zh_en.tar.bz2',
  };

  /// Get the download URL for a model
  static String getModelUrl(String modelKey) {
    final filename = availableModels[modelKey];
    if (filename == null) return '';
    return '$_modelsBaseUrl/$filename';
  }

  /// Check if models are downloaded
  static Future<bool> areModelsDownloaded() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${appDir.path}/tts_models');
      if (!modelDir.existsSync()) return false;

      final modelFile = File('${modelDir.path}/model.onnx');
      return modelFile.existsSync();
    } catch (e) {
      return false;
    }
  }
}
