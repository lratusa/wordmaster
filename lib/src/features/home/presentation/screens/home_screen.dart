import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../checkin/data/repositories/checkin_repository.dart';
import '../../../settings/application/settings_notifier.dart';
import '../../../study/data/repositories/session_repository.dart';
import '../widgets/greeting_card.dart';

/// Providers for home screen data
final _homeTodayStatsProvider = FutureProvider.autoDispose((ref) async {
  return SessionRepository().getTodayStats();
});

final _homeStreakProvider = FutureProvider.autoDispose((ref) async {
  return CheckinRepository().getStreakDays();
});

final _homeTotalWordsProvider = FutureProvider.autoDispose((ref) async {
  return CheckinRepository().getTotalWordsLearned();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayStats = ref.watch(_homeTodayStatsProvider);
    final streak = ref.watch(_homeStreakProvider);
    final totalWords = ref.watch(_homeTotalWordsProvider);
    final settings = ref.watch(settingsProvider);

    final streakDays = streak.value ?? 0;
    final stats = todayStats.value;
    final newWords = stats?.newWords ?? 0;
    final reviewWords = stats?.reviewWords ?? 0;
    final todayWordsCount = newWords + reviewWords;
    final totalWordsCount = totalWords.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GreetingCard(
              streakDays: streakDays,
              todayWords: todayWordsCount,
              totalWords: totalWordsCount,
              dailyGoal: settings.dailyNewWordsGoal,
            ),
            const SizedBox(height: 16),
            _buildSummaryCard(context, todayStats, streak, totalWords),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 16),
            _buildTodayStats(context, todayStats),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    AsyncValue<({int newWords, int reviewWords, int correctCount, int totalMinutes})> todayStats,
    AsyncValue<int> streak,
    AsyncValue<int> totalWords,
  ) {
    final streakDays = streak.value ?? 0;
    final stats = todayStats.value;
    final newWords = stats?.newWords ?? 0;
    final reviewWords = stats?.reviewWords ?? 0;
    final correctCount = stats?.correctCount ?? 0;
    final total = newWords + reviewWords;
    final correctRate = total > 0 ? (correctCount / total * 100).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department,
                    color: streakDays > 0
                        ? AppColors.streakFire
                        : AppColors.textSecondary,
                    size: 28),
                const SizedBox(width: 8),
                Text(
                  '连续打卡 $streakDays 天',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '已掌握 ${totalWords.value ?? 0} 词',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '$newWords', '今日新词'),
                _buildStatItem(context, '$reviewWords', '今日复习'),
                _buildStatItem(context, '$correctRate%', '正确率'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷操作',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.school,
                label: '开始学习',
                color: AppColors.primary,
                onTap: () => context.push('/study/setup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.headphones,
                label: '听力训练',
                color: AppColors.accent,
                onTap: () => context.push('/audio-review/setup'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.article,
                label: '今日短文',
                color: AppColors.success,
                onTap: () => context.push('/ai-passage'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.emoji_events,
                label: '打卡',
                color: AppColors.checkinGold,
                onTap: () => context.push('/checkin'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStats(
    BuildContext context,
    AsyncValue<({int newWords, int reviewWords, int correctCount, int totalMinutes})> todayStats,
  ) {
    final stats = todayStats.value;
    final minutes = stats?.totalMinutes ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日学习时间',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: minutes > 0
                    ? Text(
                        '$minutes 分钟',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      )
                    : const Text(
                        '选择一个词单开始学习吧！',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
