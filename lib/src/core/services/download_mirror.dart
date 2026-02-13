/// Download region for mirror selection.
enum DownloadRegion {
  /// International (GitHub) — default
  international,

  /// China mainland mirror (self-hosted server)
  china,
}

/// Resolves download base URLs based on region setting.
///
/// Two independent settings control word list and TTS model sources:
/// - `wordlist_download_region`: 'international' or 'china'
/// - `tts_download_region`: 'international' or 'china'
class DownloadMirror {
  DownloadMirror._();

  // === Wordlist URLs ===
  static const String _wordlistInternational =
      'https://raw.githubusercontent.com/lratusa/wordmaster-wordlists/main';
  static const String _wordlistChina =
      'http://47.93.144.50/wordmaster/wordlists';

  // === TTS Model URLs ===
  static const String _ttsInternational =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models';
  static const String _ttsChina =
      'http://47.93.144.50/wordmaster/tts-models';

  /// Get the base URL for word list downloads.
  static String wordlistBaseUrl(DownloadRegion region) {
    switch (region) {
      case DownloadRegion.international:
        return _wordlistInternational;
      case DownloadRegion.china:
        return _wordlistChina;
    }
  }

  /// Get the base URL for TTS model downloads.
  static String ttsBaseUrl(DownloadRegion region) {
    switch (region) {
      case DownloadRegion.international:
        return _ttsInternational;
      case DownloadRegion.china:
        return _ttsChina;
    }
  }

  /// Parse a region string from settings.
  static DownloadRegion parseRegion(String? value) {
    if (value == 'china') return DownloadRegion.china;
    return DownloadRegion.international;
  }

  /// Convert a region to its string value for storage.
  static String regionToString(DownloadRegion region) {
    switch (region) {
      case DownloadRegion.international:
        return 'international';
      case DownloadRegion.china:
        return 'china';
    }
  }
}
