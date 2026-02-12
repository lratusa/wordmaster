import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../word_lists/application/word_list_providers.dart';
import '../../../word_lists/domain/enums/language.dart';
import '../../../word_lists/domain/models/word_list.dart';
import '../../application/audio_review_notifier.dart';

class AudioReviewSetupScreen extends ConsumerStatefulWidget {
  const AudioReviewSetupScreen({super.key});

  @override
  ConsumerState<AudioReviewSetupScreen> createState() =>
      _AudioReviewSetupScreenState();
}

class _AudioReviewSetupScreenState
    extends ConsumerState<AudioReviewSetupScreen> {
  int? _selectedWordListId;
  int _wordLimit = 20;
  AudioMode _mode = AudioMode.manual;

  @override
  Widget build(BuildContext context) {
    final wordListsAsync = ref.watch(allWordListsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('听力设置')),
      body: wordListsAsync.when(
        data: (wordLists) {
          if (wordLists.isEmpty) {
            return const Center(
              child: Text('请先导入词单并完成一些学习',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Word list selection
                Text(
                  '选择词单',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...wordLists.map((wl) => _buildWordListTile(wl)),

                const SizedBox(height: 24),

                // Word limit
                Text(
                  '练习数量',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _wordLimit.toDouble(),
                        min: 10,
                        max: 50,
                        divisions: 8,
                        label: '$_wordLimit',
                        onChanged: (v) =>
                            setState(() => _wordLimit = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_wordLimit',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Mode selection
                Text(
                  '练习模式',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildModeTile(
                  title: '手动模式',
                  subtitle: '播放单词后手动翻看答案并评分',
                  icon: Icons.touch_app,
                  mode: AudioMode.manual,
                ),
                const SizedBox(height: 8),
                _buildModeTile(
                  title: '自动模式',
                  subtitle: '自动播放 → 5秒后显示答案 → 3秒后下一个（通勤免手操作）',
                  icon: Icons.autorenew,
                  mode: AudioMode.auto,
                ),

                const SizedBox(height: 32),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                        _selectedWordListId != null ? _startAudioReview : null,
                    icon: const Icon(Icons.headphones),
                    label: const Text(
                      '开始听力训练',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildWordListTile(WordList wordList) {
    final isSelected = _selectedWordListId == wordList.id;
    final badgeColor = wordList.language == Language.en
        ? AppColors.englishBadge
        : AppColors.japaneseBadge;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(
          wordList.language == Language.en ? Icons.school : Icons.language,
          color: badgeColor,
        ),
        title: Text(wordList.name),
        subtitle:
            Text('${wordList.wordCount} 词 · 已学 ${wordList.learnedCount}'),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : null,
        onTap: () {
          setState(() => _selectedWordListId = wordList.id);
        },
      ),
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required AudioMode mode,
  }) {
    final isSelected = _mode == mode;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primary : null),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : null,
        onTap: () => setState(() => _mode = mode),
      ),
    );
  }

  void _startAudioReview() {
    if (_selectedWordListId == null) return;

    final settings = AudioReviewSettings(
      wordListId: _selectedWordListId!,
      wordLimit: _wordLimit,
      mode: _mode,
    );

    ref.read(audioReviewProvider.notifier).startSession(settings);
    context.go('/audio-review/session');
  }
}
