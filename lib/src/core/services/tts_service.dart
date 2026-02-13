import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'download_mirror.dart';

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

/// Text-to-speech service using hybrid approach:
/// - English/Chinese: sherpa-onnx (Kokoro model, high quality offline)
/// - Japanese: System TTS via flutter_tts (Windows SAPI, reliable for Japanese)
class TtsService {
  sherpa_onnx.OfflineTts? _tts;
  AudioPlayer? _player;
  FlutterTts? _systemTts;  // For Japanese via system TTS
  bool _isInitialized = false;
  bool _initFailed = false;
  bool _systemTtsAvailable = false;
  String _modelDir = '';
  double _speed = 1.0;
  String? _lastError;

  /// Whether the current model is Kokoro
  bool _isKokoroModel = false;

  /// The actual directory containing the active model files
  String? _activeModelDir;

  /// Languages supported by sherpa-onnx model
  Set<String> _sherpaLanguages = {'en', 'zh'};

  /// Japanese is handled by system TTS
  static const String _japaneseLanguage = 'ja';

  /// Speaker ID mapping for Kokoro model (Japanese voices)
  static const Map<String, int> _kokoroJapaneseSpeakers = {
    'jf_alpha': 37,    // Female
    'jf_gongitsune': 38,
    'jf_nezumi': 39,
    'jf_tebukuro': 40,
    'jm_kumo': 41,     // Male
  };

  /// Default speaker IDs by language for Kokoro model
  static const Map<String, int> _kokoroDefaultSpeakers = {
    'en': 0,      // af_heart (American female)
    'en-gb': 7,   // bf_emma (British female)
    'ja': 37,     // jf_alpha (Japanese female)
    'zh': 42,     // Chinese speaker (if available)
  };

  /// Check if TTS is supported on current platform
  bool get isSupported => Platform.isWindows || Platform.isAndroid || Platform.isIOS || Platform.isLinux || Platform.isMacOS;

  /// Check if TTS is ready
  bool get isReady => _isInitialized && _tts != null;

  /// Check if TTS initialization failed
  bool get initFailed => _initFailed;

  /// Get the last error message
  String? get lastError => _lastError;

  /// Check if Japanese is supported (via system TTS)
  bool get supportsJapanese => _systemTtsAvailable;

  /// Get TTS status as a string for debugging
  String get status {
    final parts = <String>[];
    if (_isInitialized && _tts != null) {
      final modelType = _isKokoroModel ? 'Kokoro' : 'VITS';
      parts.add('$modelType: EN/ZH');
    }
    if (_systemTtsAvailable) {
      parts.add('System: JA');
    }
    if (parts.isNotEmpty) {
      return 'Ready (${parts.join(", ")})';
    }
    if (_initFailed) return 'Failed: ${_lastError ?? "Unknown error"}';
    return 'Not initialized';
  }

  /// Check if a language is supported by TTS
  bool isLanguageSupported(String language) {
    // Japanese is always supported via system TTS
    if (language == _japaneseLanguage) {
      return _systemTtsAvailable;
    }
    // Other languages use sherpa-onnx
    return _sherpaLanguages.contains(language);
  }

  /// Get a user-friendly message for unsupported language
  String getUnsupportedLanguageMessage(String language) {
    if (language == 'ja' && !_systemTtsAvailable) {
      return '系统日语语音不可用，请在Windows设置中安装日语语音包';
    }
    return '该语言暂不支持语音播放';
  }

  /// Reset the TTS service to allow re-initialization
  void reset() {
    _tts?.free();
    _tts = null;
    _isInitialized = false;
    _initFailed = false;
    _lastError = null;
    _isKokoroModel = false;
    _activeModelDir = null;
    _sherpaLanguages = {'en', 'zh'};
    // Note: Don't reset _systemTts as it's independent
  }

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Reset failed state to allow retry
    _initFailed = false;
    _lastError = null;

    // Initialize system TTS for Japanese (flutter_tts)
    await _initializeSystemTts();

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

      // Detect model type and create config
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

      final modelType = _isKokoroModel ? 'Kokoro' : 'VITS';
      debugPrint('TTS: Initialized successfully with $modelType model');
      debugPrint('TTS: Sherpa languages: $_sherpaLanguages');
      debugPrint('TTS: Japanese (system TTS): ${_systemTtsAvailable ? "available" : "not available"}');
    } catch (e, stack) {
      _lastError = e.toString();
      debugPrint('TTS initialization failed: $e');
      debugPrint('Stack: $stack');
      _initFailed = true;
    }
  }

  /// Initialize system TTS (flutter_tts) for Japanese
  Future<void> _initializeSystemTts() async {
    try {
      _systemTts = FlutterTts();

      // On Windows, check voices directly (more reliable than getLanguages)
      if (Platform.isWindows) {
        final voices = await _systemTts!.getVoices;
        debugPrint('TTS: System voices count: ${voices.length}');

        // Look for Japanese voice (ja-JP)
        String? japaneseVoice;
        for (final voice in voices) {
          final voiceMap = voice as Map<dynamic, dynamic>?;
          final locale = voiceMap?['locale']?.toString() ?? '';
          final name = voiceMap?['name']?.toString() ?? '';
          debugPrint('TTS: Voice: $name, locale: $locale');

          if (locale.toLowerCase().startsWith('ja')) {
            japaneseVoice = name;
            break;
          }
        }

        if (japaneseVoice != null) {
          await _systemTts!.setLanguage('ja-JP');
          await _systemTts!.setSpeechRate(0.5);  // Slightly slower for clarity
          await _systemTts!.setVolume(1.0);
          _systemTtsAvailable = true;
          debugPrint('TTS: System TTS initialized for Japanese (voice: $japaneseVoice)');
        } else {
          debugPrint('TTS: No Japanese voice found in system TTS');
          _systemTtsAvailable = false;
        }
      } else {
        // For other platforms, use getLanguages
        final languages = await _systemTts!.getLanguages;
        final hasJapanese = languages.any((lang) =>
            lang.toString().toLowerCase().contains('ja') ||
            lang.toString().toLowerCase().contains('japan'));

        if (hasJapanese) {
          await _systemTts!.setLanguage('ja-JP');
          await _systemTts!.setSpeechRate(0.5);
          await _systemTts!.setVolume(1.0);
          _systemTtsAvailable = true;
          debugPrint('TTS: System TTS initialized for Japanese');
        } else {
          debugPrint('TTS: Japanese not available in system TTS');
          _systemTtsAvailable = false;
        }
      }
    } catch (e) {
      debugPrint('TTS: Failed to initialize system TTS: $e');
      _systemTtsAvailable = false;
    }
  }

  /// Read active model ID from active_model.txt
  Future<String?> _getActiveModelId() async {
    final activeFile = File('$_modelDir/active_model.txt');
    if (activeFile.existsSync()) {
      return activeFile.readAsStringSync().trim();
    }
    return null;
  }

  /// Detect model type and set _activeModelDir
  /// Returns true if Kokoro model found (has voices.bin), false for VITS
  /// Priority: active_model.txt > VITS models (en-us-*, en-gb-*, zh-*) > Kokoro
  Future<bool> _detectActiveModel() async {
    final dir = Directory(_modelDir);
    if (!dir.existsSync()) {
      _activeModelDir = _modelDir;
      return false;
    }

    // Priority 0: Check active_model.txt first
    final activeModelId = await _getActiveModelId();
    if (activeModelId != null && activeModelId.isNotEmpty) {
      final activeDir = Directory('$_modelDir/$activeModelId');
      if (activeDir.existsSync()) {
        // Check if it's a Kokoro model (has voices.bin)
        final voicesFile = File('${activeDir.path}/voices.bin');
        if (voicesFile.existsSync()) {
          _activeModelDir = activeDir.path;
          debugPrint('TTS: Using active Kokoro model: $activeModelId');
          return true;
        }
        // Check if it's a VITS model (has .onnx file)
        await for (final file in activeDir.list()) {
          if (file is File && file.path.endsWith('.onnx')) {
            _activeModelDir = activeDir.path;
            debugPrint('TTS: Using active VITS model: $activeModelId');
            return false;
          }
        }
      }
    }

    // Priority 1: Look for VITS model directories (en-us-*, en-gb-*, zh-*) - fallback auto-detection
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final dirName = entity.path.split(Platform.pathSeparator).last;
        // Check for VITS Piper models (have .onnx but no voices.bin)
        if (dirName.startsWith('en-') || dirName.startsWith('zh-')) {
          // Look for .onnx file
          await for (final file in entity.list()) {
            if (file is File && file.path.endsWith('.onnx')) {
              _activeModelDir = entity.path;
              debugPrint('TTS: Found VITS model in ${entity.path} (auto-detected)');
              return false;  // Not Kokoro
            }
          }
        }
      }
    }

    // Priority 2: Check for Kokoro model (has voices.bin)
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final voicesFile = File('${entity.path}/voices.bin');
        final modelFile = File('${entity.path}/model.onnx');
        if (voicesFile.existsSync() && modelFile.existsSync()) {
          _activeModelDir = entity.path;
          debugPrint('TTS: Found Kokoro model in ${entity.path} (auto-detected)');
          return true;
        }
      }
    }

    // Fallback to model dir
    _activeModelDir = _modelDir;
    return false;
  }

  /// Find voices.bin file for Kokoro model
  Future<String?> _findVoicesFile() async {
    // Use _activeModelDir which was set by _detectActiveModel
    final modelDir = _activeModelDir ?? _modelDir;
    final voicesFile = File('$modelDir/voices.bin');
    if (voicesFile.existsSync()) {
      return voicesFile.path;
    }
    return null;
  }

  /// Find lexicon files for Kokoro model
  Future<String> _findLexiconFiles() async {
    final lexicons = <String>[];
    final modelDir = _activeModelDir ?? _modelDir;

    // Check for lexicon files in the active model directory
    final possibleLexicons = ['lexicon-us-en.txt', 'lexicon-zh.txt', 'lexicon.txt'];

    for (final lexiconName in possibleLexicons) {
      final lexiconFile = File('$modelDir/$lexiconName');
      if (lexiconFile.existsSync()) {
        lexicons.add(lexiconFile.path);
      }
    }

    return lexicons.join(',');
  }

  /// Find the model file in the active model directory
  Future<String?> _findModelFile() async {
    final modelDir = _activeModelDir ?? _modelDir;
    final dir = Directory(modelDir);
    if (!dir.existsSync()) return null;

    debugPrint('TTS: Searching for model in $modelDir');

    // Priority 1: Look for model.onnx (standard name for Kokoro and many models)
    final standardModel = File('$modelDir/model.onnx');
    if (standardModel.existsSync()) {
      debugPrint('TTS: Using model file: model.onnx');
      return standardModel.path;
    }

    // Priority 2: Look for any .onnx file (VITS models have different names)
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.endsWith('.onnx') && !name.contains('encoder') && !name.contains('int8')) {
          debugPrint('TTS: Using model file: $name');
          return entity.path;
        }
      }
    }

    debugPrint('TTS: No .onnx model file found in $modelDir');
    return null;
  }

  /// Find tokens.txt file in active model directory
  Future<String?> _findTokensFile() async {
    final modelDir = _activeModelDir ?? _modelDir;
    final tokensFile = File('$modelDir/tokens.txt');
    if (tokensFile.existsSync()) {
      return tokensFile.path;
    }
    return null;
  }

  /// Find espeak-ng-data directory in active model directory
  Future<String?> _findDataDir() async {
    final modelDir = _activeModelDir ?? _modelDir;
    final dataDir = Directory('$modelDir/espeak-ng-data');
    if (dataDir.existsSync()) {
      return dataDir.path;
    }
    return null;
  }

  /// Create TTS configuration based on available models
  Future<sherpa_onnx.OfflineTtsConfig?> _createTtsConfig() async {
    try {
      // Detect model type (respects active_model.txt)
      _isKokoroModel = await _detectActiveModel();
      debugPrint('TTS: Detected model type: ${_isKokoroModel ? "Kokoro" : "VITS"}');

      // Find common files
      final modelPath = await _findModelFile();
      if (modelPath == null) {
        debugPrint('TTS: No .onnx model file found in $_modelDir');
        return null;
      }

      final tokensPath = await _findTokensFile();
      if (tokensPath == null) {
        debugPrint('TTS: tokens.txt not found in $_modelDir');
        return null;
      }

      final dataDirPath = await _findDataDir();

      debugPrint('TTS: Model: $modelPath');
      debugPrint('TTS: Tokens: $tokensPath');
      debugPrint('TTS: Data dir: ${dataDirPath ?? "not found"}');

      sherpa_onnx.OfflineTtsModelConfig modelConfig;

      if (_isKokoroModel) {
        // Kokoro model configuration
        final voicesPath = await _findVoicesFile();
        final lexiconPaths = await _findLexiconFiles();

        debugPrint('TTS: Voices: ${voicesPath ?? "not found"}');
        debugPrint('TTS: Lexicons: $lexiconPaths');

        // Note: lang parameter sets the default language for espeak-ng phonemizer
        // 'ja' enables Japanese phoneme processing for hiragana/katakana
        // TODO: Consider language-specific TTS instances for better multi-lang support
        final kokoroConfig = sherpa_onnx.OfflineTtsKokoroModelConfig(
          model: modelPath,
          voices: voicesPath ?? '',
          tokens: tokensPath,
          dataDir: dataDirPath ?? '',
          lexicon: lexiconPaths,
          lang: 'ja',  // Enable Japanese phoneme processing
        );

        modelConfig = sherpa_onnx.OfflineTtsModelConfig(
          kokoro: kokoroConfig,
          numThreads: 2,
          debug: true,
          provider: 'cpu',
        );

        // Kokoro supports Japanese!
        _sherpaLanguages = {'en', 'en-gb', 'ja', 'zh'};
      } else {
        // VITS model configuration
        final vitsConfig = sherpa_onnx.OfflineTtsVitsModelConfig(
          model: modelPath,
          tokens: tokensPath,
          lexicon: '',
          dataDir: dataDirPath ?? '',
        );

        modelConfig = sherpa_onnx.OfflineTtsModelConfig(
          vits: vitsConfig,
          numThreads: 2,
          debug: true,
          provider: 'cpu',
        );

        // VITS models typically support EN and ZH
        _sherpaLanguages = {'en', 'zh'};
      }

      return sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      );
    } catch (e) {
      debugPrint('TTS: Failed to create config: $e');
      return null;
    }
  }

  /// Get the speaker ID for a given language (for Kokoro model)
  int _getSpeakerIdForLanguage(String language) {
    if (!_isKokoroModel) return 0;
    return _kokoroDefaultSpeakers[language] ?? 0;
  }

  /// Speak the given text in the specified language.
  /// Returns a [TtsSpeakResult] indicating success or the type of failure.
  Future<TtsSpeakResult> speak(String text, {String language = 'en'}) async {
    if (text.isEmpty) return TtsSpeakResult.emptyText;

    // Try to initialize if not already done
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }

    // Check if language is supported (after initialization)
    if (!isLanguageSupported(language)) {
      debugPrint('TTS: Language "$language" is not supported');
      return TtsSpeakResult.languageNotSupported;
    }

    // Japanese uses system TTS (flutter_tts)
    if (language == _japaneseLanguage) {
      return _speakWithSystemTts(text);
    }

    // Other languages use sherpa-onnx
    try {

      if (_tts == null || _initFailed) {
        debugPrint('TTS: Sherpa-onnx not available, skipping speech');
        return TtsSpeakResult.notInitialized;
      }

      // Get speaker ID based on language
      final speakerId = _getSpeakerIdForLanguage(language);

      // Generate audio with sherpa-onnx
      debugPrint('TTS: Generating speech (sherpa-onnx): ${text.substring(0, text.length.clamp(0, 50))}... (lang: $language, sid: $speakerId)');
      final audio = _tts!.generate(text: text, sid: speakerId, speed: _speed);

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

  /// Speak Japanese text using system TTS (flutter_tts)
  Future<TtsSpeakResult> _speakWithSystemTts(String text) async {
    if (_systemTts == null || !_systemTtsAvailable) {
      debugPrint('TTS: System TTS not available for Japanese');
      return TtsSpeakResult.notInitialized;
    }

    try {
      // Stop any ongoing speech first
      await stop();

      debugPrint('TTS: Speaking Japanese (system TTS): ${text.substring(0, text.length.clamp(0, 50))}...');
      await _systemTts!.speak(text);
      return TtsSpeakResult.success;
    } catch (e) {
      debugPrint('TTS: System TTS speak failed: $e');
      _lastError = e.toString();
      return TtsSpeakResult.error;
    }
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    try {
      await _player?.stop();
      await _systemTts?.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// Set the speech rate (0.5 to 2.0).
  Future<void> setSpeechRate(double rate) async {
    _speed = rate.clamp(0.5, 2.0);
  }

  /// Check if a language is available for TTS.
  Future<bool> isLanguageAvailable(String language) async {
    if (!isLanguageSupported(language)) {
      return false;
    }
    return _isInitialized && !_initFailed;
  }

  void dispose() {
    try {
      _player?.dispose();
      _tts?.free();
      _systemTts?.stop();
    } catch (e) {
      debugPrint('TTS dispose failed: $e');
    }
  }
}

/// Helper class to download and manage TTS models
class TtsModelManager {
  /// Available models for download (filename only, base URL resolved via DownloadMirror)
  static const Map<String, String> availableModels = {
    'en-us': 'vits-piper-en_US-libritts_r-medium.tar.bz2',
    'en-gb': 'vits-piper-en_GB-cori-medium.tar.bz2',
    'zh': 'vits-melo-tts-zh_en.tar.bz2',
    'kokoro': 'kokoro-multi-lang-v1_0.tar.bz2',
  };

  /// Get the download URL for a model
  static String getModelUrl(String modelKey, {DownloadRegion region = DownloadRegion.international}) {
    final filename = availableModels[modelKey];
    if (filename == null) return '';
    final base = DownloadMirror.ttsBaseUrl(region);
    return '$base/$filename';
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
