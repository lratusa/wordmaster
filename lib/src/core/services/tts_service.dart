import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service supporting English and Japanese.
/// Note: TTS is currently disabled on Windows due to stability issues.
class TtsService {
  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _initFailed = false;
  String _currentLanguage = 'en-US';

  /// Check if TTS is supported on current platform
  bool get isSupported => !Platform.isWindows;

  Future<FlutterTts?> _getTts() async {
    // Disable TTS on Windows due to crash issues
    if (Platform.isWindows) {
      debugPrint('TTS disabled on Windows');
      _initFailed = true;
      return null;
    }

    if (_initFailed) return null;
    if (_tts != null) return _tts;

    try {
      _tts = FlutterTts();
      return _tts;
    } catch (e) {
      debugPrint('TTS creation failed: $e');
      _initFailed = true;
      return null;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized || _initFailed) return;

    // Skip on Windows
    if (Platform.isWindows) {
      _initFailed = true;
      return;
    }

    try {
      final tts = await _getTts();
      if (tts == null) return;

      if (Platform.isLinux || Platform.isMacOS) {
        await tts.awaitSpeakCompletion(true);
      }

      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
      _initFailed = true;
    }
  }

  /// Speak the given text in the specified language.
  /// [language] should be 'en' or 'ja'.
  Future<void> speak(String text, {String language = 'en'}) async {
    try {
      await _ensureInitialized();
      final tts = _tts;
      if (tts == null || _initFailed) return;

      final lang = language == 'ja' ? 'ja-JP' : 'en-US';
      if (lang != _currentLanguage) {
        await tts.setLanguage(lang);
        _currentLanguage = lang;
      }

      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    try {
      final tts = _tts;
      if (tts == null) return;
      await tts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// Set the speech rate (0.0 to 1.0).
  Future<void> setSpeechRate(double rate) async {
    try {
      await _ensureInitialized();
      final tts = _tts;
      if (tts == null || _initFailed) return;
      await tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('TTS setSpeechRate failed: $e');
    }
  }

  /// Check if a language is available.
  Future<bool> isLanguageAvailable(String language) async {
    try {
      await _ensureInitialized();
      final tts = _tts;
      if (tts == null || _initFailed) return false;
      final lang = language == 'ja' ? 'ja-JP' : 'en-US';
      final result = await tts.isLanguageAvailable(lang);
      return result == true || result == 1;
    } catch (e) {
      debugPrint('TTS isLanguageAvailable failed: $e');
      return false;
    }
  }

  void dispose() {
    try {
      _tts?.stop();
    } catch (e) {
      debugPrint('TTS dispose failed: $e');
    }
  }
}
