import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'download_mirror.dart';

/// Word list category
enum WordListCategory {
  cefr,    // CEFR A1-C2
  cet,     // CET-4, CET-6
  kaoyan,  // 考研
  gaokao,  // 高考
  zhongkao, // 中考
  toefl,   // TOEFL
  sat,     // SAT
  delf,    // DELF/DALF (French proficiency exams)
  jlpt,    // JLPT N5-N1
  jlptKanji, // JLPT Kanji N5-N1
  schoolKanji, // School Kanji (Grade 1-6, Middle, High)
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
  /// Available word list packages organized by category.
  /// The [url] field stores a relative path; the base URL is resolved
  /// at download time via [DownloadMirror] based on the user's region setting.
  static const List<WordListPackage> availablePackages = [
    // ========== CEFR (欧标) A1-C2 ==========
    WordListPackage(id: 'cefr-a1', name: 'CEFR A1 入门级', nameEn: 'CEFR A1 (Beginner)', language: 'en', description: '欧洲语言共同参考框架 A1 级别，适合零基础学习者', level: 'A1', category: WordListCategory.cefr, url: 'english/cefr_a1.json', wordCount: 500, iconName: 'school'),
    WordListPackage(id: 'cefr-a2', name: 'CEFR A2 基础级', nameEn: 'CEFR A2 (Elementary)', language: 'en', description: '欧洲语言共同参考框架 A2 级别，掌握基本日常用语', level: 'A2', category: WordListCategory.cefr, url: 'english/cefr_a2.json', wordCount: 1000, iconName: 'menu_book'),
    WordListPackage(id: 'cefr-b1', name: 'CEFR B1 中级', nameEn: 'CEFR B1 (Intermediate)', language: 'en', description: '欧洲语言共同参考框架 B1 级别，能够应对日常交流', level: 'B1', category: WordListCategory.cefr, url: 'english/cefr_b1.json', wordCount: 1500, iconName: 'auto_stories'),
    WordListPackage(id: 'cefr-b2', name: 'CEFR B2 中高级', nameEn: 'CEFR B2 (Upper-Intermediate)', language: 'en', description: '欧洲语言共同参考框架 B2 级别，能够流利表达观点', level: 'B2', category: WordListCategory.cefr, url: 'english/cefr_b2.json', wordCount: 2000, iconName: 'local_library'),
    WordListPackage(id: 'cefr-c1', name: 'CEFR C1 高级', nameEn: 'CEFR C1 (Advanced)', language: 'en', description: '欧洲语言共同参考框架 C1 级别，能够进行复杂学术讨论', level: 'C1', category: WordListCategory.cefr, url: 'english/cefr_c1.json', wordCount: 2000, iconName: 'psychology'),
    WordListPackage(id: 'cefr-c2', name: 'CEFR C2 精通级', nameEn: 'CEFR C2 (Proficiency)', language: 'en', description: '欧洲语言共同参考框架 C2 级别，接近母语水平', level: 'C2', category: WordListCategory.cefr, url: 'english/cefr_c2.json', wordCount: 1500, iconName: 'workspace_premium'),
    // ========== CEFR 法语 A1-C2 ==========
    WordListPackage(id: 'cefr-fr-a1', name: 'CEFR A1 法语入门', nameEn: 'CEFR A1 French', language: 'fr', description: '法语 A1 级别，适合零基础学习者', level: 'A1', category: WordListCategory.cefr, url: 'french/cefr_a1.json', wordCount: 500, iconName: 'school'),
    WordListPackage(id: 'cefr-fr-a2', name: 'CEFR A2 法语基础', nameEn: 'CEFR A2 French', language: 'fr', description: '法语 A2 级别，掌握基本日常用语', level: 'A2', category: WordListCategory.cefr, url: 'french/cefr_a2.json', wordCount: 1000, iconName: 'menu_book'),
    WordListPackage(id: 'cefr-fr-b1', name: 'CEFR B1 法语中级', nameEn: 'CEFR B1 French', language: 'fr', description: '法语 B1 级别，能够应对日常交流', level: 'B1', category: WordListCategory.cefr, url: 'french/cefr_b1.json', wordCount: 1500, iconName: 'auto_stories'),
    WordListPackage(id: 'cefr-fr-b2', name: 'CEFR B2 法语中高级', nameEn: 'CEFR B2 French', language: 'fr', description: '法语 B2 级别，能够流利表达观点', level: 'B2', category: WordListCategory.cefr, url: 'french/cefr_b2.json', wordCount: 2000, iconName: 'local_library'),
    WordListPackage(id: 'cefr-fr-c1', name: 'CEFR C1 法语高级', nameEn: 'CEFR C1 French', language: 'fr', description: '法语 C1 级别，能够进行复杂学术讨论', level: 'C1', category: WordListCategory.cefr, url: 'french/cefr_c1.json', wordCount: 2500, iconName: 'psychology'),
    WordListPackage(id: 'cefr-fr-c2', name: 'CEFR C2 法语精通', nameEn: 'CEFR C2 French', language: 'fr', description: '法语 C2 级别，接近母语水平', level: 'C2', category: WordListCategory.cefr, url: 'french/cefr_c2.json', wordCount: 3000, iconName: 'workspace_premium'),
    // ========== DELF/DALF 法语水平考试 ==========
    WordListPackage(id: 'delf-a1', name: 'DELF A1', nameEn: 'DELF A1', language: 'fr', description: '法语学习证书 A1 级别考试词汇', level: 'A1', category: WordListCategory.delf, url: 'french/delf_a1.json', wordCount: 500, iconName: 'workspace_premium'),
    WordListPackage(id: 'delf-a2', name: 'DELF A2', nameEn: 'DELF A2', language: 'fr', description: '法语学习证书 A2 级别考试词汇', level: 'A2', category: WordListCategory.delf, url: 'french/delf_a2.json', wordCount: 1000, iconName: 'workspace_premium'),
    WordListPackage(id: 'delf-b1', name: 'DELF B1', nameEn: 'DELF B1', language: 'fr', description: '法语学习证书 B1 级别考试词汇', level: 'B1', category: WordListCategory.delf, url: 'french/delf_b1.json', wordCount: 1500, iconName: 'workspace_premium'),
    WordListPackage(id: 'delf-b2', name: 'DELF B2', nameEn: 'DELF B2', language: 'fr', description: '法语学习证书 B2 级别考试词汇', level: 'B2', category: WordListCategory.delf, url: 'french/delf_b2.json', wordCount: 2000, iconName: 'workspace_premium'),
    WordListPackage(id: 'dalf-c1', name: 'DALF C1', nameEn: 'DALF C1', language: 'fr', description: '法语高级水平证书 C1 级别考试词汇', level: 'C1', category: WordListCategory.delf, url: 'french/dalf_c1.json', wordCount: 2500, iconName: 'workspace_premium'),
    WordListPackage(id: 'dalf-c2', name: 'DALF C2', nameEn: 'DALF C2', language: 'fr', description: '法语高级水平证书 C2 级别考试词汇', level: 'C2', category: WordListCategory.delf, url: 'french/dalf_c2.json', wordCount: 3000, iconName: 'workspace_premium'),
    // ========== CET 四六级 ==========
    WordListPackage(id: 'cet4-full', name: '四级词汇', nameEn: 'CET-4 Vocabulary', language: 'en', description: '大学英语四级考试词汇表', level: 'CET-4', category: WordListCategory.cet, url: 'english/cet4-full.json', wordCount: 4500, iconName: 'school'),
    WordListPackage(id: 'cet6-core', name: '六级核心词汇', nameEn: 'CET-6 Core Vocabulary', language: 'en', description: '大学英语六级考试核心高频词汇', level: 'CET-6', category: WordListCategory.cet, url: 'english/cet6_core.json', wordCount: 2000, iconName: 'auto_stories'),
    WordListPackage(id: 'cet6-full', name: '六级完整词汇', nameEn: 'CET-6 Full Vocabulary', language: 'en', description: '大学英语六级考试完整词汇表', level: 'CET-6', category: WordListCategory.cet, url: 'english/cet6_full.json', wordCount: 5500, iconName: 'local_library'),
    // ========== TOEFL 托福 ==========
    WordListPackage(id: 'toefl-core', name: '托福核心词汇', nameEn: 'TOEFL Core Vocabulary', language: 'en', description: 'TOEFL 考试核心高频词汇', level: 'TOEFL', category: WordListCategory.toefl, url: 'english/toefl-core.json', wordCount: 3000, iconName: 'flight_takeoff'),
    WordListPackage(id: 'toefl-full', name: '托福完整词汇', nameEn: 'TOEFL Full Vocabulary', language: 'en', description: 'TOEFL 考试完整词汇表', level: 'TOEFL', category: WordListCategory.toefl, url: 'english/toefl-full.json', wordCount: 8000, iconName: 'public'),
    // ========== SAT ==========
    WordListPackage(id: 'sat-core', name: 'SAT 核心词汇', nameEn: 'SAT Core Vocabulary', language: 'en', description: 'SAT 考试核心高频词汇', level: 'SAT', category: WordListCategory.sat, url: 'english/sat_core.json', wordCount: 2500, iconName: 'school'),
    WordListPackage(id: 'sat-full', name: 'SAT 完整词汇', nameEn: 'SAT Full Vocabulary', language: 'en', description: 'SAT 考试完整词汇表', level: 'SAT', category: WordListCategory.sat, url: 'english/sat_full.json', wordCount: 5000, iconName: 'menu_book'),
    // ========== 考研 ==========
    WordListPackage(id: 'kaoyan-core', name: '考研核心词汇', nameEn: 'Graduate Entrance Exam Core', language: 'en', description: '考研英语核心高频词汇', level: '考研', category: WordListCategory.kaoyan, url: 'english/kaoyan_core.json', wordCount: 3000, iconName: 'school'),
    WordListPackage(id: 'kaoyan-full', name: '考研完整词汇', nameEn: 'Graduate Entrance Exam Full', language: 'en', description: '考研英语大纲完整词汇表', level: '考研', category: WordListCategory.kaoyan, url: 'english/kaoyan_full.json', wordCount: 5500, iconName: 'menu_book'),
    // ========== 高考 ==========
    WordListPackage(id: 'gaokao-core', name: '高考核心词汇', nameEn: 'College Entrance Exam Core', language: 'en', description: '高考英语核心高频词汇', level: '高考', category: WordListCategory.gaokao, url: 'english/gaokao_core.json', wordCount: 2000, iconName: 'school'),
    WordListPackage(id: 'gaokao-full', name: '高考完整词汇', nameEn: 'College Entrance Exam Full', language: 'en', description: '高考英语大纲完整词汇表', level: '高考', category: WordListCategory.gaokao, url: 'english/gaokao_full.json', wordCount: 3500, iconName: 'menu_book'),
    // ========== 中考 ==========
    WordListPackage(id: 'zhongkao-core', name: '中考核心词汇', nameEn: 'High School Entrance Exam Core', language: 'en', description: '中考英语核心高频词汇', level: '中考', category: WordListCategory.zhongkao, url: 'english/zhongkao_core.json', wordCount: 1200, iconName: 'school'),
    WordListPackage(id: 'zhongkao-full', name: '中考完整词汇', nameEn: 'High School Entrance Exam Full', language: 'en', description: '中考英语大纲完整词汇表', level: '中考', category: WordListCategory.zhongkao, url: 'english/zhongkao_full.json', wordCount: 1600, iconName: 'menu_book'),
    // ========== JLPT 日语能力考试 词汇 ==========
    WordListPackage(id: 'jlpt-n5', name: 'JLPT N5 词汇', nameEn: 'JLPT N5 Vocabulary', language: 'ja', description: '日语能力考试 N5 级别基础词汇', level: 'N5', category: WordListCategory.jlpt, url: 'japanese/jlpt_n5.json', wordCount: 800, iconName: 'translate'),
    WordListPackage(id: 'jlpt-n4', name: 'JLPT N4 词汇', nameEn: 'JLPT N4 Vocabulary', language: 'ja', description: '日语能力考试 N4 级别初级词汇', level: 'N4', category: WordListCategory.jlpt, url: 'japanese/jlpt_n4.json', wordCount: 1500, iconName: 'language'),
    WordListPackage(id: 'jlpt-n3', name: 'JLPT N3 词汇', nameEn: 'JLPT N3 Vocabulary', language: 'ja', description: '日语能力考试 N3 级别中级词汇', level: 'N3', category: WordListCategory.jlpt, url: 'japanese/jlpt_n3.json', wordCount: 3000, iconName: 'g_translate'),
    WordListPackage(id: 'jlpt-n2', name: 'JLPT N2 词汇', nameEn: 'JLPT N2 Vocabulary', language: 'ja', description: '日语能力考试 N2 级别中高级词汇', level: 'N2', category: WordListCategory.jlpt, url: 'japanese/jlpt_n2.json', wordCount: 5000, iconName: 'history_edu'),
    WordListPackage(id: 'jlpt-n1', name: 'JLPT N1 词汇', nameEn: 'JLPT N1 Vocabulary', language: 'ja', description: '日语能力考试 N1 级别高级词汇', level: 'N1', category: WordListCategory.jlpt, url: 'japanese/jlpt_n1.json', wordCount: 8000, iconName: 'workspace_premium'),
    // ========== JLPT 日语汉字 ==========
    WordListPackage(id: 'jlpt-kanji-n5', name: 'JLPT N5 汉字', nameEn: 'JLPT N5 Kanji', language: 'ja', description: '日语能力考试 N5 级别汉字 (约100字)', level: 'N5', category: WordListCategory.jlptKanji, url: 'japanese/jlpt_kanji_n5.json', wordCount: 100, iconName: 'translate'),
    WordListPackage(id: 'jlpt-kanji-n4', name: 'JLPT N4 汉字', nameEn: 'JLPT N4 Kanji', language: 'ja', description: '日语能力考试 N4 级别汉字 (约300字)', level: 'N4', category: WordListCategory.jlptKanji, url: 'japanese/jlpt_kanji_n4.json', wordCount: 300, iconName: 'language'),
    WordListPackage(id: 'jlpt-kanji-n3', name: 'JLPT N3 汉字', nameEn: 'JLPT N3 Kanji', language: 'ja', description: '日语能力考试 N3 级别汉字 (约600字)', level: 'N3', category: WordListCategory.jlptKanji, url: 'japanese/jlpt_kanji_n3.json', wordCount: 600, iconName: 'g_translate'),
    WordListPackage(id: 'jlpt-kanji-n2', name: 'JLPT N2 汉字', nameEn: 'JLPT N2 Kanji', language: 'ja', description: '日语能力考试 N2 级别汉字 (约1000字)', level: 'N2', category: WordListCategory.jlptKanji, url: 'japanese/jlpt_kanji_n2.json', wordCount: 1000, iconName: 'history_edu'),
    WordListPackage(id: 'jlpt-kanji-n1', name: 'JLPT N1 汉字', nameEn: 'JLPT N1 Kanji', language: 'ja', description: '日语能力考试 N1 级别汉字 (约2000字)', level: 'N1', category: WordListCategory.jlptKanji, url: 'japanese/jlpt_kanji_n1.json', wordCount: 2000, iconName: 'workspace_premium'),
    // ========== 日本学校汉字 (常用汉字) ==========
    WordListPackage(id: 'school-kanji-grade1', name: '小学一年级汉字', nameEn: 'Grade 1 Kanji', language: 'ja', description: '日本小学一年级教育汉字 (80字)', level: '小1', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_grade1.json', wordCount: 80, iconName: 'child_care'),
    WordListPackage(id: 'school-kanji-grade2', name: '小学二年级汉字', nameEn: 'Grade 2 Kanji', language: 'ja', description: '日本小学二年级教育汉字 (160字)', level: '小2', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_grade2.json', wordCount: 160, iconName: 'child_care'),
    WordListPackage(id: 'school-kanji-grade3', name: '小学三年级汉字', nameEn: 'Grade 3 Kanji', language: 'ja', description: '日本小学三年级教育汉字 (200字)', level: '小3', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_grade3.json', wordCount: 200, iconName: 'school'),
    WordListPackage(id: 'school-kanji-grade4', name: '小学四年级汉字', nameEn: 'Grade 4 Kanji', language: 'ja', description: '日本小学四年级教育汉字 (202字)', level: '小4', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_grade4.json', wordCount: 202, iconName: 'school'),
    WordListPackage(id: 'school-kanji-grade5', name: '小学五年级汉字', nameEn: 'Grade 5 Kanji', language: 'ja', description: '日本小学五年级教育汉字 (193字)', level: '小5', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_grade5.json', wordCount: 193, iconName: 'menu_book'),
    WordListPackage(id: 'school-kanji-grade6', name: '小学六年级汉字', nameEn: 'Grade 6 Kanji', language: 'ja', description: '日本小学六年级教育汉字 (191字)', level: '小6', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_grade6.json', wordCount: 191, iconName: 'menu_book'),
    WordListPackage(id: 'school-kanji-middle', name: '中学汉字', nameEn: 'Middle School Kanji', language: 'ja', description: '日本中学教育汉字 (常用汉字表追加字)', level: '中学', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_middle.json', wordCount: 1110, iconName: 'history_edu'),
    WordListPackage(id: 'school-kanji-high', name: '高中汉字', nameEn: 'High School Kanji', language: 'ja', description: '日本高中常用汉字补充', level: '高中', category: WordListCategory.schoolKanji, url: 'japanese/school_kanji_high.json', wordCount: 196, iconName: 'workspace_premium'),
  ];

  /// Resolve the full download URL for a package.
  static String resolveUrl(WordListPackage package, DownloadRegion region) {
    final base = DownloadMirror.wordlistBaseUrl(region);
    return '$base/${package.url}';
  }

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

  /// Download a word list package.
  /// [region] determines which mirror to use for the download URL.
  Future<Map<String, dynamic>> downloadPackage(
    WordListPackage package, {
    DownloadProgressCallback? onProgress,
    DownloadRegion region = DownloadRegion.international,
  }) async {
    final cacheDir = await getCacheDirectory();
    await Directory(cacheDir).create(recursive: true);

    final filePath = '$cacheDir/${package.id}.json';
    final downloadUrl = resolveUrl(package, region);

    try {
      debugPrint('WordList: Downloading ${package.name} from $downloadUrl');

      final response = await _dio.get(
        downloadUrl,
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

  /// Get a package by name
  static WordListPackage? getPackageByName(String name) {
    return availablePackages.where((p) => p.name == name).firstOrNull;
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
    WordListCategory.zhongkao,
    WordListCategory.gaokao,
    WordListCategory.cet,
    WordListCategory.kaoyan,
    WordListCategory.toefl,
    WordListCategory.sat,
  ];

  /// Get all Japanese categories
  static List<WordListCategory> get japaneseCategories => [
    WordListCategory.jlpt,
    WordListCategory.jlptKanji,
    WordListCategory.schoolKanji,
  ];

  /// Get all French categories
  static List<WordListCategory> get frenchCategories => [
    WordListCategory.cefr,  // French also uses CEFR
    WordListCategory.delf,  // DELF/DALF exams
  ];

  /// Get category display name
  static String getCategoryName(WordListCategory category) {
    switch (category) {
      case WordListCategory.cefr:
        return 'CEFR 欧标';
      case WordListCategory.zhongkao:
        return '中考';
      case WordListCategory.gaokao:
        return '高考';
      case WordListCategory.cet:
        return '四六级 CET';
      case WordListCategory.kaoyan:
        return '考研';
      case WordListCategory.toefl:
        return '托福 TOEFL';
      case WordListCategory.sat:
        return 'SAT';
      case WordListCategory.delf:
        return 'DELF/DALF';
      case WordListCategory.jlpt:
        return 'JLPT 词汇';
      case WordListCategory.jlptKanji:
        return 'JLPT 汉字';
      case WordListCategory.schoolKanji:
        return '日本学校汉字';
    }
  }

  /// Get category icon
  static String getCategoryIcon(WordListCategory category) {
    switch (category) {
      case WordListCategory.cefr:
        return 'public';
      case WordListCategory.zhongkao:
        return 'school';
      case WordListCategory.gaokao:
        return 'history_edu';
      case WordListCategory.cet:
        return 'school';
      case WordListCategory.kaoyan:
        return 'science';
      case WordListCategory.toefl:
        return 'flight_takeoff';
      case WordListCategory.sat:
        return 'menu_book';
      case WordListCategory.delf:
        return 'workspace_premium';
      case WordListCategory.jlpt:
        return 'translate';
      case WordListCategory.jlptKanji:
        return 'language';
      case WordListCategory.schoolKanji:
        return 'child_care';
    }
  }
}
