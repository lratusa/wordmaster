import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/study_session_notifier.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studySessionProvider);
    final theme = Theme.of(context);
    final minutes = (session.durationSeconds / 60).ceil();
    final correctRate = (session.correctRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习总结'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Result icon
            Icon(
              correctRate >= 80
                  ? Icons.emoji_events
                  : correctRate >= 60
                      ? Icons.thumb_up
                      : Icons.sentiment_neutral,
              size: 72,
              color: correctRate >= 80
                  ? AppColors.checkinGold
                  : correctRate >= 60
                      ? AppColors.success
                      : AppColors.warning,
            ),
            const SizedBox(height: 16),
            Text(
              correctRate >= 80
                  ? '太棒了！'
                  : correctRate >= 60
                      ? '不错！'
                      : '继续加油！',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            // Stats grid
            _buildStatsGrid(
              context,
              stats: [
                _StatItem(
                  label: '学习单词',
                  value: '${session.totalReviewed}',
                  icon: Icons.book,
                  color: AppColors.primary,
                ),
                _StatItem(
                  label: '新学单词',
                  value: '${session.newWordsCount}',
                  icon: Icons.fiber_new,
                  color: AppColors.success,
                ),
                _StatItem(
                  label: '正确率',
                  value: '$correctRate%',
                  icon: Icons.check_circle,
                  color: correctRate >= 80
                      ? AppColors.success
                      : AppColors.warning,
                ),
                _StatItem(
                  label: '学习时长',
                  value: '$minutes 分钟',
                  icon: Icons.timer,
                  color: AppColors.info,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Action buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => context.go('/checkin'),
                icon: const Icon(Icons.emoji_events),
                label: const Text(
                  '去打卡',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: const Text(
                  '返回首页',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context,
      {required List<_StatItem> stats}) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: stats.map((stat) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(stat.icon, color: stat.color, size: 28),
                const SizedBox(height: 8),
                Text(
                  stat.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: stat.color,
                      ),
                ),
                Text(
                  stat.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
