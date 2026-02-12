import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Word list category
enum WordListCategory {
  cefr,    // CEFR A1-C2
  cet,     // CET-4, CET-6
  toefl,   // TOEFL
  ielts,   // IELTS
  gre,     // GRE
  jlpt,    // JLPT N5-N1
}

/// Word list package information
class WordListPackage {
  final String id;
  final String name;
  final String nameEn;
  final String language; // 'en' or 'ja'
  final String description;
  final String level; // CEFR level (A1-C2), JLPT (N5-N1), or exam name
  final WordListCategory category;
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
    required this.category,
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

  /// Available word list packages organized by category
  /// English: CEFR, CET-4/6, TOEFL, IELTS, GRE
  /// Japanese: JLPT levels
  static const List<WordListPackage> availablePackages = [
    // ========== CEFR (欧标) A1-C2 ==========
    WordListPackage(
      id: 'cefr-a1',
      name: 'CEFR A1 入门级',
      nameEn: 'CEFR A1 (Beginner)',
      language: 'en',
      description: '欧洲语言共同参考框架 A1 级别，适合零基础学习者',
      level: 'A1',
      category: WordListCategory.cefr,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-a1.json',
      wordCount: 500,
      iconName: 'school',
    ),
    WordListPackage(
      id: 'cefr-a2',
      name: 'CEFR A2 基础级',
      nameEn: 'CEFR A2 (Elementary)',
      language: 'en',
      description: '欧洲语言共同参考框架 A2 级别，掌握基本日常用语',
      level: 'A2',
      category: WordListCategory.cefr,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-a2.json',
      wordCount: 1000,
      iconName: 'menu_book',
    ),
    WordListPackage(
      id: 'cefr-b1',
      name: 'CEFR B1 中级',
      nameEn: 'CEFR B1 (Intermediate)',
      language: 'en',
      description: '欧洲语言共同参考框架 B1 级别，能够应对日常交流',
      level: 'B1',
      category: WordListCategory.cefr,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-b1.json',
      wordCount: 1500,
      iconName: 'auto_stories',
    ),
    WordListPackage(
      id: 'cefr-b2',
      name: 'CEFR B2 中高级',
      nameEn: 'CEFR B2 (Upper-Intermediate)',
      language: 'en',
      description: '欧洲语言共同参考框架 B2 级别，能够流利表达观点',
      level: 'B2',
      category: WordListCategory.cefr,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-b2.json',
      wordCount: 2000,
      iconName: 'local_library',
    ),
    WordListPackage(
      id: 'cefr-c1',
      name: 'CEFR C1 高级',
      nameEn: 'CEFR C1 (Advanced)',
      language: 'en',
      description: '欧洲语言共同参考框架 C1 级别，能够进行复杂学术讨论',
      level: 'C1',
      category: WordListCategory.cefr,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-c1.json',
      wordCount: 2000,
      iconName: 'psychology',
    ),
    WordListPackage(
      id: 'cefr-c2',
      name: 'CEFR C2 精通级',
      nameEn: 'CEFR C2 (Proficiency)',
      language: 'en',
      description: '欧洲语言共同参考框架 C2 级别，接近母语水平',
      level: 'C2',
      category: WordListCategory.cefr,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cefr-c2.json',
      wordCount: 1500,
      iconName: 'workspace_premium',
    ),

    // ========== CET 四六级 ==========
    WordListPackage(
      id: 'cet4-core',
      name: '四级核心词汇',
      nameEn: 'CET-4 Core Vocabulary',
      language: 'en',
      description: '大学英语四级考试核心高频词汇',
      level: 'CET-4',
      category: WordListCategory.cet,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cet4-core.json',
      wordCount: 2500,
      iconName: 'school',
    ),
    WordListPackage(
      id: 'cet4-full',
      name: '四级完整词汇',
      nameEn: 'CET-4 Full Vocabulary',
      language: 'en',
      description: '大学英语四级考试完整词汇表',
      level: 'CET-4',
      category: WordListCategory.cet,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cet4-full.json',
      wordCount: 4500,
      iconName: 'menu_book',
    ),
    WordListPackage(
      id: 'cet6-core',
      name: '六级核心词汇',
      nameEn: 'CET-6 Core Vocabulary',
      language: 'en',
      description: '大学英语六级考试核心高频词汇',
      level: 'CET-6',
      category: WordListCategory.cet,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cet6-core.json',
      wordCount: 2000,
      iconName: 'auto_stories',
    ),
    WordListPackage(
      id: 'cet6-full',
      name: '六级完整词汇',
      nameEn: 'CET-6 Full Vocabulary',
      language: 'en',
      description: '大学英语六级考试完整词汇表',
      level: 'CET-6',
      category: WordListCategory.cet,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/cet6-full.json',
      wordCount: 5500,
      iconName: 'local_library',
    ),

    // ========== TOEFL 托福 ==========
    WordListPackage(
      id: 'toefl-core',
      name: '托福核心词汇',
      nameEn: 'TOEFL Core Vocabulary',
      language: 'en',
      description: 'TOEFL 考试核心高频词汇',
      level: 'TOEFL',
      category: WordListCategory.toefl,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/toefl-core.json',
      wordCount: 3000,
      iconName: 'flight_takeoff',
    ),
    WordListPackage(
      id: 'toefl-full',
      name: '托福完整词汇',
      nameEn: 'TOEFL Full Vocabulary',
      language: 'en',
      description: 'TOEFL 考试完整词汇表',
      level: 'TOEFL',
      category: WordListCategory.toefl,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/toefl-full.json',
      wordCount: 8000,
      iconName: 'public',
    ),
    WordListPackage(
      id: 'toefl-academic',
      name: '托福学术词汇',
      nameEn: 'TOEFL Academic Vocabulary',
      language: 'en',
      description: 'TOEFL 学术场景高频词汇',
      level: 'TOEFL',
      category: WordListCategory.toefl,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/toefl-academic.json',
      wordCount: 2000,
      iconName: 'biotech',
    ),

    // ========== IELTS 雅思 ==========
    WordListPackage(
      id: 'ielts-core',
      name: '雅思核心词汇',
      nameEn: 'IELTS Core Vocabulary',
      language: 'en',
      description: 'IELTS 考试核心高频词汇',
      level: 'IELTS',
      category: WordListCategory.ielts,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/ielts-core.json',
      wordCount: 3000,
      iconName: 'travel_explore',
    ),
    WordListPackage(
      id: 'ielts-full',
      name: '雅思完整词汇',
      nameEn: 'IELTS Full Vocabulary',
      language: 'en',
      description: 'IELTS 考试完整词汇表',
      level: 'IELTS',
      category: WordListCategory.ielts,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/ielts-full.json',
      wordCount: 7000,
      iconName: 'language',
    ),
    WordListPackage(
      id: 'ielts-academic',
      name: '雅思学术词汇',
      nameEn: 'IELTS Academic Vocabulary',
      language: 'en',
      description: 'IELTS 学术类考试高频词汇',
      level: 'IELTS',
      category: WordListCategory.ielts,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/ielts-academic.json',
      wordCount: 2500,
      iconName: 'science',
    ),

    // ========== GRE ==========
    WordListPackage(
      id: 'gre-core',
      name: 'GRE 核心词汇',
      nameEn: 'GRE Core Vocabulary',
      language: 'en',
      description: 'GRE 考试核心高频词汇',
      level: 'GRE',
      category: WordListCategory.gre,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/gre-core.json',
      wordCount: 3000,
      iconName: 'psychology',
    ),
    WordListPackage(
      id: 'gre-full',
      name: 'GRE 完整词汇',
      nameEn: 'GRE Full Vocabulary',
      language: 'en',
      description: 'GRE 考试完整词汇表',
      level: 'GRE',
      category: WordListCategory.gre,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/gre-full.json',
      wordCount: 8000,
      iconName: 'menu_book',
    ),
    WordListPackage(
      id: 'gre-advanced',
      name: 'GRE 高难词汇',
      nameEn: 'GRE Advanced Vocabulary',
      language: 'en',
      description: 'GRE 高难度低频词汇',
      level: 'GRE',
      category: WordListCategory.gre,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/english/gre-advanced.json',
      wordCount: 2000,
      iconName: 'workspace_premium',
    ),

    // ========== JLPT 日语能力考试 ==========
    WordListPackage(
      id: 'jlpt-n5',
      name: 'JLPT N5',
      nameEn: 'JLPT N5 (Beginner)',
      language: 'ja',
      description: '日语能力考试 N5 级别基础词汇',
      level: 'N5',
      category: WordListCategory.jlpt,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n5.json',
      wordCount: 800,
      iconName: 'translate',
    ),
    WordListPackage(
      id: 'jlpt-n4',
      name: 'JLPT N4',
      nameEn: 'JLPT N4 (Elementary)',
      language: 'ja',
      description: '日语能力考试 N4 级别初级词汇',
      level: 'N4',
      category: WordListCategory.jlpt,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n4.json',
      wordCount: 1500,
      iconName: 'language',
    ),
    WordListPackage(
      id: 'jlpt-n3',
      name: 'JLPT N3',
      nameEn: 'JLPT N3 (Intermediate)',
      language: 'ja',
      description: '日语能力考试 N3 级别中级词汇',
      level: 'N3',
      category: WordListCategory.jlpt,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n3.json',
      wordCount: 3000,
      iconName: 'g_translate',
    ),
    WordListPackage(
      id: 'jlpt-n2',
      name: 'JLPT N2',
      nameEn: 'JLPT N2 (Upper-Intermediate)',
      language: 'ja',
      description: '日语能力考试 N2 级别中高级词汇',
      level: 'N2',
      category: WordListCategory.jlpt,
      url: '$_githubRaw/lratusa/wordmaster-wordlists/main/japanese/jlpt-n2.json',
      wordCount: 5000,
      iconName: 'history_edu',
    ),
    WordListPackage(
      id: 'jlpt-n1',
      name: 'JLPT N1',
      nameEn: 'JLPT N1 (Advanced)',
      language: 'ja',
      description: '日语能力考试 N1 级别高级词汇',
      level: 'N1',
      category: WordListCategory.jlpt,
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

  /// Get packages by category
  static List<WordListPackage> getPackagesByCategory(WordListCategory category) {
    return availablePackages.where((p) => p.category == category).toList();
  }

  /// Get all English exam categories
  static List<WordListCategory> get englishCategories => [
    WordListCategory.cefr,
    WordListCategory.cet,
    WordListCategory.toefl,
    WordListCategory.ielts,
    WordListCategory.gre,
  ];

  /// Get category display name
  static String getCategoryName(WordListCategory category) {
    switch (category) {
      case WordListCategory.cefr:
        return 'CEFR 欧标';
      case WordListCategory.cet:
        return '四六级';
      case WordListCategory.toefl:
        return '托福 TOEFL';
      case WordListCategory.ielts:
        return '雅思 IELTS';
      case WordListCategory.gre:
        return 'GRE';
      case WordListCategory.jlpt:
        return 'JLPT 日语能力考';
    }
  }

  /// Get category icon
  static String getCategoryIcon(WordListCategory category) {
    switch (category) {
      case WordListCategory.cefr:
        return 'public';
      case WordListCategory.cet:
        return 'school';
      case WordListCategory.toefl:
        return 'flight_takeoff';
      case WordListCategory.ielts:
        return 'travel_explore';
      case WordListCategory.gre:
        return 'psychology';
      case WordListCategory.jlpt:
        return 'translate';
    }
  }
}
