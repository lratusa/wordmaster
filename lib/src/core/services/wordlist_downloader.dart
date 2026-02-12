import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Word list package information
class WordListPackage {
  final String id;
  final String name;
  final String nameEn;
  final String language; // 'en' or 'ja'
  final String description;
  final String level; // CEFR level (A1-C2) or JLPT level (N5-N1)
  final String url;
  final int wordCount;
  final String iconName;

  const WordListPackage({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.language,
    required this.description,
    required this.level,
    required this.url,
    required this.wordCount,
    required this.iconName,
  });
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(int received, int total);

/// Word List Downloader - handles downloading word list packages
class WordListDownloader {
  static const String _githubRaw = 'https://raw.githubusercontent.com';

  /// Available word list packages
  /// English: CEFR levels from Words-CEFR-Dataset
  /// Japanese: JLPT levels from various sources
  static const List<WordListPackage> availablePackages = [
    // English - CEFR Levels
    WordListPackage(
      id: 'en-a1',
      name: '基础英语 A1',
      nameEn: 'English A1 (Beginner)',
      language: 'en',
      description: 'CEFR A1 级别基础词汇',
      level: 'A1',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-a1.json',
      wordCount: 500,
      iconName: 'school',
    ),
    WordListPackage(
      id: 'en-a2',
      name: '初级英语 A2',
      nameEn: 'English A2 (Elementary)',
      language: 'en',
      description: 'CEFR A2 级别初级词汇',
      level: 'A2',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-a2.json',
      wordCount: 1000,
      iconName: 'menu_book',
    ),
    WordListPackage(
      id: 'en-b1',
      name: '中级英语 B1',
      nameEn: 'English B1 (Intermediate)',
      language: 'en',
      description: 'CEFR B1 级别中级词汇',
      level: 'B1',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-b1.json',
      wordCount: 2000,
      iconName: 'auto_stories',
    ),
    WordListPackage(
      id: 'en-b2',
      name: '中高级英语 B2',
      nameEn: 'English B2 (Upper-Intermediate)',
      language: 'en',
      description: 'CEFR B2 级别中高级词汇',
      level: 'B2',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-b2.json',
      wordCount: 3000,
      iconName: 'local_library',
    ),
    WordListPackage(
      id: 'en-c1',
      name: '高级英语 C1',
      nameEn: 'English C1 (Advanced)',
      language: 'en',
      description: 'CEFR C1 级别高级词汇',
      level: 'C1',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-c1.json',
      wordCount: 2500,
      iconName: 'psychology',
    ),
    // Japanese - JLPT Levels
    WordListPackage(
      id: 'ja-n5',
      name: 'JLPT N5',
      nameEn: 'JLPT N5 (Beginner)',
      language: 'ja',
      description: '日语能力考试 N5 级别基础词汇',
      level: 'N5',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n5.json',
      wordCount: 800,
      iconName: 'translate',
    ),
    WordListPackage(
      id: 'ja-n4',
      name: 'JLPT N4',
      nameEn: 'JLPT N4 (Elementary)',
      language: 'ja',
      description: '日语能力考试 N4 级别初级词汇',
      level: 'N4',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n4.json',
      wordCount: 1500,
      iconName: 'language',
    ),
    WordListPackage(
      id: 'ja-n3',
      name: 'JLPT N3',
      nameEn: 'JLPT N3 (Intermediate)',
      language: 'ja',
      description: '日语能力考试 N3 级别中级词汇',
      level: 'N3',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n3.json',
      wordCount: 3000,
      iconName: 'g_translate',
    ),
    WordListPackage(
      id: 'ja-n2',
      name: 'JLPT N2',
      nameEn: 'JLPT N2 (Upper-Intermediate)',
      language: 'ja',
      description: '日语能力考试 N2 级别中高级词汇',
      level: 'N2',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n2.json',
      wordCount: 5000,
      iconName: 'history_edu',
    ),
    WordListPackage(
      id: 'ja-n1',
      name: 'JLPT N1',
      nameEn: 'JLPT N1 (Advanced)',
      language: 'ja',
      description: '日语能力考试 N1 级别高级词汇',
      level: 'N1',
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n1.json',
      wordCount: 8000,
      iconName: 'workspace_premium',
    ),
  ];

  final Dio _dio = Dio();

  /// Get the word lists cache directory
  Future<String> getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/wordlist_cache';
  }

  /// Check if a word list is downloaded
  Future<bool> isPackageDownloaded(String packageId) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File('$cacheDir/$packageId.json');
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Get list of downloaded packages
  Future<List<String>> getDownloadedPackages() async {
    final downloaded = <String>[];
    for (final pkg in availablePackages) {
      if (await isPackageDownloaded(pkg.id)) {
        downloaded.add(pkg.id);
      }
    }
    return downloaded;
  }

  /// Download a word list package
  Future<Map<String, dynamic>> downloadPackage(
    WordListPackage package, {
    DownloadProgressCallback? onProgress,
  }) async {
    final cacheDir = await getCacheDirectory();
    await Directory(cacheDir).create(recursive: true);

    final filePath = '$cacheDir/${package.id}.json';

    try {
      debugPrint('WordList: Downloading ${package.name}...');

      final response = await _dio.get(
        package.url,
        onReceiveProgress: onProgress,
        options: Options(responseType: ResponseType.plain),
      );

      // Parse JSON to validate
      final data = jsonDecode(response.data as String) as Map<String, dynamic>;

      // Save to cache
      await File(filePath).writeAsString(response.data as String);

      debugPrint('WordList: ${package.name} downloaded successfully');
      return data;
    } catch (e) {
      debugPrint('WordList: Download failed: $e');
      // Clean up on failure
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
      }
      rethrow;
    }
  }

  /// Load a cached word list package
  Future<Map<String, dynamic>?> loadCachedPackage(String packageId) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File('$cacheDir/$packageId.json');
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('WordList: Failed to load cached package: $e');
      return null;
    }
  }

  /// Delete a downloaded package
  Future<void> deletePackage(String packageId) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File('$cacheDir/$packageId.json');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('WordList: Failed to delete package: $e');
    }
  }

  /// Get packages by language
  static List<WordListPackage> getPackagesByLanguage(String language) {
    return availablePackages.where((p) => p.language == language).toList();
  }
}
