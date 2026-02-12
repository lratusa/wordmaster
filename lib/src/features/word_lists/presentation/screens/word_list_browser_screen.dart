import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/word_list_providers.dart';
import '../../domain/enums/language.dart';
import '../../domain/models/word.dart';
import '../../domain/models/word_list.dart';

class WordListBrowserScreen extends ConsumerStatefulWidget {
  const WordListBrowserScreen({super.key});

  @override
  ConsumerState<WordListBrowserScreen> createState() =>
      _WordListBrowserScreenState();
}

class _WordListBrowserScreenState
    extends ConsumerState<WordListBrowserScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索单词...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    ref.read(wordSearchQueryProvider.notifier).setQuery(value);
                  },
                )
              : const Text('词单'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    ref.read(wordSearchQueryProvider.notifier).setQuery('');
                  }
                });
              },
            ),
          ],
          bottom: _isSearching
              ? null
              : const TabBar(
                  tabs: [
                    Tab(text: '英语'),
                    Tab(text: '日语'),
                  ],
                ),
        ),
        body: _isSearching
            ? _buildSearchResults()
            : const TabBarView(
                children: [
                  _WordListTab(language: Language.en),
                  _WordListTab(language: Language.ja),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResults = ref.watch(wordSearchResultsProvider);
    final query = ref.watch(wordSearchQueryProvider);

    if (query.isEmpty) {
      return const Center(
        child: Text(
          '输入关键词搜索单词',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return searchResults.when(
      data: (words) {
        if (words.isEmpty) {
          return const Center(
            child: Text(
              '没有找到匹配的单词',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          itemCount: words.length,
          itemBuilder: (context, index) {
            return _WordSearchTile(word: words[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('搜索出错: $e')),
    );
  }
}

class _WordListTab extends ConsumerWidget {
  final Language language;

  const _WordListTab({required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListsAsync = ref.watch(wordListsByLanguageProvider(language));

    return wordListsAsync.when(
      data: (wordLists) {
        if (wordLists.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  '暂无词单',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text(
                  '内置词单正在加载中...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: wordLists.length,
          itemBuilder: (context, index) {
            return _WordListCard(wordList: wordLists[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
    );
  }
}

class _WordListCard extends StatelessWidget {
  final WordList wordList;

  const _WordListCard({required this.wordList});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = wordList.progress;
    final badgeColor = wordList.language == Language.en
        ? AppColors.englishBadge
        : AppColors.japaneseBadge;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          if (wordList.id != null) {
            context.push('/word-lists/${wordList.id}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIcon(wordList.iconName),
                    color: badgeColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wordList.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (wordList.description != null)
                          Text(
                            wordList.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          wordList.language.chineseName,
                          style: TextStyle(
                            fontSize: 11,
                            color: badgeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${wordList.wordCount} 词',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            AppColors.textSecondary.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${wordList.learnedCount}/${wordList.wordCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (wordList.reviewDueCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${wordList.reviewDueCount} 个待复习',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school;
      case 'language':
        return Icons.language;
      case 'book':
        return Icons.book;
      default:
        return Icons.list_alt;
    }
  }
}

class _WordSearchTile extends StatelessWidget {
  final Word word;

  const _WordSearchTile({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isJapanese = word.language == Language.ja;
    final badgeColor =
        isJapanese ? AppColors.japaneseBadge : AppColors.englishBadge;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isJapanese ? '日' : 'EN',
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      title: Text(
        word.word,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Row(
        children: [
          if (word.displayReading.isNotEmpty) ...[
            Text(
              word.displayReading,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              word.translationCn,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
