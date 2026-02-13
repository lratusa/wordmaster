import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/wordlist_downloader.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/word_list_providers.dart';
import '../../data/repositories/word_list_repository.dart';
import '../../domain/enums/language.dart';
import '../../domain/models/word.dart';
import '../../domain/models/word_list.dart';

/// Screen for browsing and downloading word list packages
class WordListDownloadScreen extends ConsumerStatefulWidget {
  const WordListDownloadScreen({super.key});

  @override
  ConsumerState<WordListDownloadScreen> createState() =>
      _WordListDownloadScreenState();
}

class _WordListDownloadScreenState
    extends ConsumerState<WordListDownloadScreen> {
  final WordListDownloader _downloader = WordListDownloader();
  final WordListRepository _repository = WordListRepository();

  final Map<String, bool> _downloadedPackages = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  bool _isLoading = true;
  WordListCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadDownloadedPackages();
  }

  Future<void> _loadDownloadedPackages() async {
    setState(() => _isLoading = true);

    final downloaded = await _downloader.getDownloadedPackages();
    for (final pkg in WordListDownloader.availablePackages) {
      _downloadedPackages[pkg.id] = downloaded.contains(pkg.id);
      _isDownloading[pkg.id] = false;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _downloadPackage(WordListPackage package) async {
    setState(() {
      _isDownloading[package.id] = true;
      _downloadProgress[package.id] = 0;
    });

    try {
      final data = await _downloader.downloadPackage(
        package,
        onProgress: (received, total) {
          setState(() {
            _downloadProgress[package.id] = received / total;
          });
        },
      );

      // Import to database
      await _importPackageToDatabase(package, data);

      // Invalidate providers to refresh word list on other screens
      ref.invalidate(allWordListsProvider);
      ref.invalidate(wordListsByLanguageProvider(Language.fromCode(package.language)));

      setState(() {
        _downloadedPackages[package.id] = true;
        _isDownloading[package.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${package.name} 下载完成'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading[package.id] = false;
      });

      if (mounted) {
        // Parse error for user-friendly message
        String errorMessage;
        if (e.toString().contains('404')) {
          errorMessage = '该词库暂未上线，敬请期待';
        } else if (e.toString().contains('SocketException') ||
            e.toString().contains('Connection')) {
          errorMessage = '网络连接失败，请检查网络后重试';
        } else if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          errorMessage = '下载超时，请稍后重试';
        } else {
          errorMessage = '下载失败，请稍后重试';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: e.toString().contains('404')
                ? AppColors.warning
                : AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importPackageToDatabase(
    WordListPackage package,
    Map<String, dynamic> data,
  ) async {
    final language = Language.fromCode(package.language);
    final wordsJson = data['words'] as List<dynamic>;

    final wordList = WordList(
      name: data['name'] as String? ?? package.name,
      language: language,
      description: data['description'] as String? ?? package.description,
      type: WordListType.builtIn,
      wordCount: wordsJson.length,
      iconName: data['icon_name'] as String? ?? package.iconName,
    );

    final words = wordsJson.map((w) {
      final wordMap = w as Map<String, dynamic>;
      final examplesJson = wordMap['examples'] as List<dynamic>? ?? [];

      return Word(
        wordListId: 0,
        language: language,
        word: wordMap['word'] as String,
        translationCn: wordMap['translation_cn'] as String,
        partOfSpeech: wordMap['part_of_speech'] as String?,
        difficultyLevel: wordMap['difficulty_level'] as int? ?? 1,
        phonetic: wordMap['phonetic'] as String?,
        reading: wordMap['reading'] as String?,
        jlptLevel: wordMap['jlpt_level'] as String?,
        exampleSentences: examplesJson.map((e) {
          final exMap = e as Map<String, dynamic>;
          return ExampleSentence(
            wordId: 0,
            sentence: exMap['sentence'] as String,
            translationCn: exMap['translation_cn'] as String,
          );
        }).toList(),
      );
    }).toList();

    await _repository.importWordListWithWords(wordList, words);
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      null, // All
      ...WordListDownloader.englishCategories,
      WordListCategory.jlpt,
    ];

    final filteredPackages = _selectedCategory == null
        ? WordListDownloader.availablePackages
        : WordListDownloader.getPackagesByCategory(_selectedCategory!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载词库'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      final label = category == null
                          ? '全部'
                          : WordListDownloader.getCategoryName(category);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Package list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPackages.length,
                    itemBuilder: (context, index) {
                      final package = filteredPackages[index];
                      return _buildPackageCard(package);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPackageCard(WordListPackage package) {
    final isDownloaded = _downloadedPackages[package.id] ?? false;
    final isDownloading = _isDownloading[package.id] ?? false;
    final progress = _downloadProgress[package.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(package.category),
                  color: isDownloaded ? AppColors.success : AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              package.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isDownloaded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '已下载',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                    Icons.numbers, '${package.wordCount} 词'),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.category,
                  WordListDownloader.getCategoryName(package.category),
                ),
                const Spacer(),
                if (isDownloading)
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else if (!isDownloaded)
                  FilledButton.icon(
                    onPressed: () => _downloadPackage(package),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('下载'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(WordListCategory category) {
    switch (category) {
      case WordListCategory.cefr:
        return Icons.public;
      case WordListCategory.zhongkao:
        return Icons.school;
      case WordListCategory.gaokao:
        return Icons.history_edu;
      case WordListCategory.cet:
        return Icons.school;
      case WordListCategory.kaoyan:
        return Icons.science;
      case WordListCategory.toefl:
        return Icons.flight_takeoff;
      case WordListCategory.ielts:
        return Icons.travel_explore;
      case WordListCategory.gre:
        return Icons.psychology;
      case WordListCategory.sat:
        return Icons.menu_book;
      case WordListCategory.gmat:
        return Icons.business;
      case WordListCategory.jlpt:
        return Icons.translate;
    }
  }
}
