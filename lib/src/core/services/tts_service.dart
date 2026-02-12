import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service supporting English and Japanese.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  String _currentLanguage = 'en-US';

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _tts.awaitSpeakCompletion(true);
    }

    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  /// Speak the given text in the specified language.
  /// [language] should be 'en' or 'ja'.
  Future<void> speak(String text, {String language = 'en'}) async {
    await _ensureInitialized();

    final lang = language == 'ja' ? 'ja-JP' : 'en-US';
    if (lang != _currentLanguage) {
      await _tts.setLanguage(lang);
      _currentLanguage = lang;
    }

    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Set the speech rate (0.0 to 1.0).
  Future<void> setSpeechRate(double rate) async {
    await _ensureInitialized();
    await _tts.setSpeechRate(rate);
  }

  /// Check if a language is available.
  Future<bool> isLanguageAvailable(String language) async {
    await _ensureInitialized();
    final lang = language == 'ja' ? 'ja-JP' : 'en-US';
    final result = await _tts.isLanguageAvailable(lang);
    return result == true || result == 1;
  }

  void dispose() {
    _tts.stop();
  }
}
