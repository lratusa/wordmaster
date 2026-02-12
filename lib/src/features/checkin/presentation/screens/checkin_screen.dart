import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_colors.dart';
import '../../application/checkin_notifier.dart';
import '../../data/repositories/checkin_repository.dart';
import '../widgets/checkin_card.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(checkinProvider.notifier).loadData());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('每日打卡')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Streak display
                  _buildStreakCard(state, theme),
                  const SizedBox(height: 16),

                  // Today's stats
                  _buildTodayStats(state, theme),
                  const SizedBox(height: 16),

                  // Achievements
                  _buildAchievements(state, theme),
                  const SizedBox(height: 24),

                  // Check-in button or share button
                  if (!state.hasCheckedIn)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: (state.todayNewWords + state.todayReviewWords) > 0
                            ? () => ref.read(checkinProvider.notifier).doCheckin()
                            : null,
                        icon: const Icon(Icons.check_circle),
                        label: Text(
                          (state.todayNewWords + state.todayReviewWords) > 0
                              ? '打卡'
                              : '今天还没有学习哦',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(
                            '今日已打卡',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _shareCheckin,
                        icon: const Icon(Icons.share),
                        label: const Text('生成分享图片'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStreakCard(CheckinState state, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.local_fire_department,
              size: 48,
              color: state.streakDays > 0
                  ? AppColors.streakFire
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              '${state.streakDays}',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Text(
              '连续打卡天数',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniStat(
                    '已掌握', '${state.totalWordsLearned} 词', theme),
                const SizedBox(width: 32),
                _buildMiniStat(
                    '学习天数', '${state.totalStudyDays} 天', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTodayStats(CheckinState state, ThemeData theme) {
    final correctRate = state.todayCorrectRate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日学习',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildStatTile(
                        '新学', '${state.todayNewWords}', Icons.fiber_new,
                        AppColors.success)),
                Expanded(
                    child: _buildStatTile(
                        '复习', '${state.todayReviewWords}', Icons.refresh,
                        AppColors.primary)),
                Expanded(
                    child: _buildStatTile(
                        '正确率', '${(correctRate * 100).round()}%',
                        Icons.check_circle,
                        correctRate >= 0.8
                            ? AppColors.success
                            : AppColors.warning)),
                Expanded(
                    child: _buildStatTile(
                        '时长', '${state.todayMinutes}分',
                        Icons.timer, AppColors.info)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildAchievements(CheckinState state, ThemeData theme) {
    final unlocked =
        state.achievements.where((a) => a.isUnlocked).toList();
    if (unlocked.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '成就',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unlocked.map((a) {
                return Chip(
                  avatar: Icon(_getAchievementIcon(a.key),
                      size: 18, color: AppColors.checkinGold),
                  label: Text(a.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(String key) {
    switch (key) {
      case 'streak_1':
        return Icons.spa;
      case 'streak_3':
        return Icons.local_fire_department;
      case 'streak_7':
        return Icons.star;
      case 'streak_30':
        return Icons.emoji_events;
      case 'streak_100':
        return Icons.workspace_premium;
      case 'words_100':
        return Icons.military_tech;
      case 'words_500':
        return Icons.military_tech;
      case 'words_2000':
        return Icons.military_tech;
      default:
        return Icons.emoji_events;
    }
  }

  Future<void> _shareCheckin() async {
    final state = ref.read(checkinProvider);
    if (!state.hasCheckedIn || state.record == null) return;

    // Generate screenshot from the CheckinCard widget
    final Uint8List? imageBytes =
        await _screenshotController.captureFromLongWidget(
      CheckinCard(
        record: state.record!,
        achievements:
            state.achievements.where((a) => a.isUnlocked).toList(),
        totalWordsLearned: state.totalWordsLearned,
        totalStudyDays: state.totalStudyDays,
      ),
      delay: const Duration(milliseconds: 100),
    );

    if (imageBytes == null) return;

    // Save to temp file
    final tempDir = Directory.systemTemp;
    final file = File(p.join(tempDir.path, 'wordmaster_checkin.png'));
    await file.writeAsBytes(imageBytes);

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: show save dialog hint
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('截图已保存到: ${file.path}')),
        );
      }
    } else {
      // Mobile: share
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'WordMaster 打卡 - 连续${state.record!.streakDays}天！',
        ),
      );
    }
  }
}
