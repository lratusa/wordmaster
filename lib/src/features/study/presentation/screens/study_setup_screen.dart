import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../word_lists/application/word_list_providers.dart';
import '../../../word_lists/domain/enums/language.dart';
import '../../../word_lists/domain/models/word_list.dart';
import '../../application/study_session_notifier.dart';

class StudySetupScreen extends ConsumerStatefulWidget {
  const StudySetupScreen({super.key});

  @override
  ConsumerState<StudySetupScreen> createState() => _StudySetupScreenState();
}

class _StudySetupScreenState extends ConsumerState<StudySetupScreen> {
  int? _selectedWordListId;
  int _newWordsLimit = AppConstants.defaultNewWordsPerDay;
  int _reviewLimit = AppConstants.defaultReviewLimitPerDay;

  @override
  Widget build(BuildContext context) {
    final wordListsAsync = ref.watch(allWordListsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('学习设置')),
      body: wordListsAsync.when(
        data: (wordLists) {
          if (wordLists.isEmpty) {
            return const Center(
              child: Text(
                '请先导入词单',
                style: TextStyle(color: AppColors.textSecondary),
              ),
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

                // New words per session
                Text(
                  '每次新词数量',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _newWordsLimit.toDouble(),
                        min: 5,
                        max: 50,
                        divisions: 9,
                        label: '$_newWordsLimit',
                        onChanged: (v) =>
                            setState(() => _newWordsLimit = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_newWordsLimit',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Review limit
                Text(
                  '复习上限',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _reviewLimit.toDouble(),
                        min: 50,
                        max: 500,
                        divisions: 9,
                        label: '$_reviewLimit',
                        onChanged: (v) =>
                            setState(() => _reviewLimit = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_reviewLimit',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _selectedWordListId != null
                        ? _startStudy
                        : null,
                    icon: const Icon(Icons.school),
                    label: const Text(
                      '开始学习',
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
        subtitle: Text('${wordList.wordCount} 词 · 已学 ${wordList.learnedCount}'),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : null,
        onTap: () {
          setState(() => _selectedWordListId = wordList.id);
        },
      ),
    );
  }

  void _startStudy() {
    if (_selectedWordListId == null) return;

    final settings = StudySettings(
      wordListId: _selectedWordListId!,
      newWordsLimit: _newWordsLimit,
      reviewLimit: _reviewLimit,
    );

    ref.read(studySessionProvider.notifier).startSession(settings);
    context.go('/study/session');
  }
}
