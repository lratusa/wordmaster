import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../common_widgets/furigana_text.dart';
import '../../application/word_list_providers.dart';
import '../../domain/enums/language.dart';
import '../../domain/models/word.dart';

class WordListDetailScreen extends ConsumerWidget {
  final int wordListId;

  const WordListDetailScreen({super.key, required this.wordListId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListAsync = ref.watch(wordListByIdProvider(wordListId));
    final wordsAsync = ref.watch(wordsInListProvider(wordListId));

    return Scaffold(
      appBar: AppBar(
        title: wordListAsync.when(
          data: (wl) => Text(wl?.name ?? '词单详情'),
          loading: () => const Text('加载中...'),
          error: (_, __) => const Text('词单详情'),
        ),
        actions: [
          wordListAsync.when(
            data: (wl) {
              if (wl == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.school),
                tooltip: '开始学习',
                onPressed: () => context.push('/study/setup'),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: wordsAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return const Center(
              child: Text(
                '此词单暂无单词',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return _WordListView(
            words: words,
            wordListId: wordListId,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

class _WordListView extends StatelessWidget {
  final List<Word> words;
  final int wordListId;

  const _WordListView({
    required this.words,
    required this.wordListId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return _WordCard(
          word: words[index],
          index: index + 1,
        );
      },
    );
  }
}

class _WordCard extends StatefulWidget {
  final Word word;
  final int index;

  const _WordCard({required this.word, required this.index});

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = widget.word;
    final isJapanese = word.language == Language.ja;
    final badgeColor =
        isJapanese ? AppColors.japaneseBadge : AppColors.englishBadge;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main word row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Index number
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${widget.index}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Word with reading
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isJapanese)
                              InlineFurigana(
                                text: word.word,
                                reading: word.reading,
                                fontSize: 18,
                              )
                            else
                              Text(
                                word.word,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (word.partOfSpeech != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  word.partOfSpeech!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!isJapanese && word.phonetic != null)
                          Text(
                            word.phonetic!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Translation
                  Expanded(
                    child: Text(
                      word.translationCn,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              // Expanded section - example sentences
              if (_expanded && word.exampleSentences.isNotEmpty) ...[
                const Divider(height: 16),
                ...word.exampleSentences.map((sentence) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 32, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sentence.sentence,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sentence.translationCn,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
