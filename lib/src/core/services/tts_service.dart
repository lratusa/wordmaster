import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// TTS speak result
enum TtsSpeakResult {
  /// Successfully playing audio
  success,
  /// TTS not initialized or failed to initialize
  notInitialized,
  /// Language not supported
  languageNotSupported,
  /// Text was empty
  emptyText,
  /// Failed to generate audio
  generationFailed,
  /// Other error
  error,
}

/// Text-to-speech service using sherpa-onnx for offline TTS.
/// Supports English and Chinese with high-quality neural voices.
/// Note: Japanese TTS is not yet available in sherpa-onnx.
class TtsService {
  sherpa_onnx.OfflineTts? _tts;
  AudioPlayer? _player;
  bool _isInitialized = false;
  bool _initFailed = false;
  String _modelDir = '';
  double _speed = 1.0;
  String? _lastError;

  /// Languages supported by the current TTS models
  /// Japanese is NOT supported yet - sherpa-onnx doesn't have Japanese TTS models
  static const Set<String> supportedLanguages = {'en', 'zh'};

  /// Languages that are planned but not yet available
  static const Set<String> unsupportedLanguages = {'ja'};

  /// Check if TTS is supported on current platform
  bool get isSupported => Platform.isWindows || Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS;

  /// Check if TTS is ready
  bool get isReady => _isInitialized && _tts != null;

  /// Check if TTS initialization failed
  bool get initFailed => _initFailed;

  /// Get the last error message
  String? get lastError => _lastError;

  /// Get TTS status as a string for debugging
  String get status {
    if (_isInitialized && _tts != null) return 'Ready';
    if (_initFailed) return 'Failed: ${_lastError ?? "Unknown error"}';
    return 'Not initialized';
  }

  /// Check if a language is supported by TTS
  bool isLanguageSupported(String language) {
    return supportedLanguages.contains(language);
  }

  /// Get a user-friendly message for unsupported language
  String getUnsupportedLanguageMessage(String language) {
    if (language == 'ja') {
      return '日语语音暂不支持，敬请期待';  // Japanese TTS not yet supported
    }
    return '该语言暂不支持语音播放';  // This language doesn't support TTS yet
  }

  /// Reset the TTS service to allow re-initialization
  void reset() {
    _tts?.free();
    _tts = null;
    _isInitialized = false;
    _initFailed = false;
    _lastError = null;
  }

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Reset failed state to allow retry
    _initFailed = false;
    _lastError = null;

    try {
      debugPrint('TTS: Initializing sherpa-onnx...');

      // Initialize sherpa-onnx bindings
      sherpa_onnx.initBindings();

      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      _modelDir = '${appDir.path}/tts_models';

      // Check if models directory exists
      final modelDirExists = await Directory(_modelDir).exists();
      if (!modelDirExists) {
        _lastError = 'Models directory not found. Please download a TTS model first.';
        debugPrint('TTS: $_lastError');
        _initFailed = true;
        return;
      }

      // Create TTS instance with VITS model
      final config = await _createTtsConfig();
      if (config == null) {
        _lastError = 'No valid TTS model found. Please download a TTS model.';
        debugPrint('TTS: $_lastError');
        _initFailed = true;
        return;
      }

      _tts = sherpa_onnx.OfflineTts(config);
      _player = AudioPlayer();

      _isInitialized = true;
      _lastError = null;
      debugPrint('TTS: Initialized successfully');
    } catch (e, stack) {
      _lastError = e.toString();
      debugPrint('TTS initialization failed: $e');
      debugPrint('Stack: $stack');
      _initFailed = true;
    }
  }

  /// Find the model file in the model directory (searches recursively)
  Future<String?> _findModelFile() async {
    final dir = Directory(_modelDir);
    if (!dir.existsSync()) return null;

    // List all files in directory for debugging
    debugPrint('TTS: Searching for model in $_modelDir');

    // Look for .onnx files - first check top level
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        debugPrint('TTS: Found file: $name');
        if (name.endsWith('.onnx') && !name.contains('encoder')) {
          debugPrint('TTS: Using model file: $name');
          return entity.path;
        }
      }
    }

    // If not found at top level, search in subdirectories
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final subDirName = entity.path.split(Platform.pathSeparator).last;
        debugPrint('TTS: Searching subdirectory: $subDirName');
        await for (final subEntity in entity.list()) {
          if (subEntity is File) {
            final name = subEntity.path.split(Platform.pathSeparator).last;
            if (name.endsWith('.onnx') && !name.contains('encoder')) {
              debugPrint('TTS: Found model in subdirectory: $name');
              return subEntity.path;
            }
          }
        }
      }
    }

    debugPrint('TTS: No .onnx model file found');
    return null;
  }

  /// Find tokens.txt file (searches recursively)
  Future<String?> _findTokensFile() async {
    final dir = Directory(_modelDir);
    if (!dir.existsSync()) return null;

    // Check top level first
    final topLevelTokens = File('$_modelDir/tokens.txt');
    if (topLevelTokens.existsSync()) {
      return topLevelTokens.path;
    }

    // Search in subdirectories
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final tokensPath = '${entity.path}/tokens.txt';
        if (File(tokensPath).existsSync()) {
          debugPrint('TTS: Found tokens.txt in subdirectory');
          return tokensPath;
        }
      }
    }

    return null;
  }

  /// Find espeak-ng-data directory (searches recursively)
  Future<String?> _findDataDir() async {
    final dir = Directory(_modelDir);
    if (!dir.existsSync()) return null;

    // Check top level first
    final topLevelDataDir = Directory('$_modelDir/espeak-ng-data');
    if (topLevelDataDir.existsSync()) {
      return topLevelDataDir.path;
    }

    // Search in subdirectories
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final dataDirPath = '${entity.path}/espeak-ng-data';
        if (Directory(dataDirPath).existsSync()) {
          debugPrint('TTS: Found espeak-ng-data in subdirectory');
          return dataDirPath;
        }
      }
    }

    return null;
  }

  /// Create TTS configuration based on available models
  Future<sherpa_onnx.OfflineTtsConfig?> _createTtsConfig() async {
    try {
      // Find the model file dynamically (searches recursively)
      final modelPath = await _findModelFile();
      if (modelPath == null) {
        debugPrint('TTS: No .onnx model file found in $_modelDir');
        return null;
      }

      // Find tokens.txt (searches recursively)
      final tokensPath = await _findTokensFile();
      if (tokensPath == null) {
        debugPrint('TTS: tokens.txt not found in $_modelDir');
        return null;
      }

      // Find espeak-ng-data directory (searches recursively)
      final dataDirPath = await _findDataDir();

      debugPrint('TTS: Model: $modelPath');
      debugPrint('TTS: Tokens: $tokensPath');
      debugPrint('TTS: Data dir: ${dataDirPath ?? "not found"}');

      final vitsConfig = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: modelPath,
        tokens: tokensPath,
        lexicon: '',
        dataDir: dataDirPath ?? '',
      );

      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        vits: vitsConfig,
        numThreads: 2,
        debug: true, // Enable debug for troubleshooting
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
  /// [language] should be 'en' or 'zh'. Japanese ('ja') is not yet supported.
  /// Returns a [TtsSpeakResult] indicating success or the type of failure.
  Future<TtsSpeakResult> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) return TtsSpeakResult.emptyText;

    // Check if language is supported
    if (!isLanguageSupported(language)) {
      debugPrint('TTS: Language "$language" is not supported');
      return TtsSpeakResult.languageNotSupported;
    }

    try {
      // Try to initialize if not already done
      if (!_isInitialized && !_initFailed) {
        await initialize();
      }

      if (_tts == null || _initFailed) {
        debugPrint('TTS: Not available, skipping speech');
        return TtsSpeakResult.notInitialized;
      }

      // Generate audio
      debugPrint('TTS: Generating speech for: ${text.substring(0, text.length.clamp(0, 50))}...');
      final audio = _tts!.generate(text: text, sid: 0, speed: _speed);

      if (audio.samples.isEmpty) {
        debugPrint('TTS: No audio generated');
        return TtsSpeakResult.generationFailed;
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
      return TtsSpeakResult.success;
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      _lastError = e.toString();
      return TtsSpeakResult.error;
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

  /// Check if a language is available for TTS.
  /// Returns true only if the language is supported AND TTS is initialized.
  Future<bool> isLanguageAvailable(String language) async {
    // First check if the language is in the supported list
    if (!isLanguageSupported(language)) {
      return false;
    }
    // Then check if TTS is initialized
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
/// Note: Japanese TTS is not available yet in sherpa-onnx
class TtsModelManager {
  static const String _modelsBaseUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';

  /// Available models for download
  /// Note: Japanese (ja) is NOT available - sherpa-onnx doesn't have Japanese TTS models yet
  static const Map<String, String> availableModels = {
    'en-us': 'vits-piper-en_US-libritts_r-medium.tar.bz2',
    'en-gb': 'vits-piper-en_GB-cori-medium.tar.bz2',
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
