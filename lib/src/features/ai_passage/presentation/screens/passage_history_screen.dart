import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/ai_passage_notifier.dart';
import '../../domain/passage_history.dart';

class PassageHistoryScreen extends ConsumerStatefulWidget {
  const PassageHistoryScreen({super.key});

  @override
  ConsumerState<PassageHistoryScreen> createState() =>
      _PassageHistoryScreenState();
}

class _PassageHistoryScreenState extends ConsumerState<PassageHistoryScreen> {
  List<PassageHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history =
          await ref.read(aiPassageProvider.notifier).getPassageHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _deletePassage(PassageHistory passage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除短文'),
        content: const Text('确定要删除这篇短文吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.ratingAgain),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(aiPassageProvider.notifier).deletePassage(passage.id);
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      }
    }
  }

  void _openPassage(PassageHistory passage) async {
    await ref.read(aiPassageProvider.notifier).loadPassageForReview(passage.id);
    if (mounted) {
      context.go('/ai-passage');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('短文历史'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/ai-passage'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无历史记录',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '生成的短文会保存在这里',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final passage = _history[index];
                      return _buildHistoryCard(passage, theme);
                    },
                  ),
                ),
    );
  }

  Widget _buildHistoryCard(PassageHistory passage, ThemeData theme) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final scoreColor = passage.isCompleted
        ? (passage.scorePercentage ?? 0) >= 80
            ? AppColors.success
            : (passage.scorePercentage ?? 0) >= 60
                ? AppColors.warning
                : AppColors.ratingAgain
        : AppColors.textSecondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openPassage(passage),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(passage.generationDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: passage.language == 'en'
                          ? AppColors.englishBadge.withValues(alpha: 0.2)
                          : AppColors.japaneseBadge.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      passage.languageDisplay,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: passage.language == 'en'
                            ? AppColors.englishBadge
                            : AppColors.japaneseBadge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    iconSize: 20,
                    color: AppColors.textSecondary,
                    onPressed: () => _deletePassage(passage),
                    tooltip: '删除',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                passage.passagePreview,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    passage.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: scoreColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    passage.scoreDisplay,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    passage.isCompleted ? '点击重做' : '点击继续',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
