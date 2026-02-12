import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service supporting English and Japanese.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _initFailed = false;
  String _currentLanguage = 'en-US';

  Future<void> _ensureInitialized() async {
    if (_isInitialized || _initFailed) return;

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _tts.awaitSpeakCompletion(true);
      }

      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

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
      if (_initFailed) return;

      final lang = language == 'ja' ? 'ja-JP' : 'en-US';
      if (lang != _currentLanguage) {
        await _tts.setLanguage(lang);
        _currentLanguage = lang;
      }

      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// Set the speech rate (0.0 to 1.0).
  Future<void> setSpeechRate(double rate) async {
    try {
      await _ensureInitialized();
      if (_initFailed) return;
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('TTS setSpeechRate failed: $e');
    }
  }

  /// Check if a language is available.
  Future<bool> isLanguageAvailable(String language) async {
    try {
      await _ensureInitialized();
      if (_initFailed) return false;
      final lang = language == 'ja' ? 'ja-JP' : 'en-US';
      final result = await _tts.isLanguageAvailable(lang);
      return result == true || result == 1;
    } catch (e) {
      debugPrint('TTS isLanguageAvailable failed: $e');
      return false;
    }
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (e) {
      debugPrint('TTS dispose failed: $e');
    }
  }
}
