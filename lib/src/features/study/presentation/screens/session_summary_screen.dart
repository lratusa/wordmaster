import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_colors.dart';
import '../../application/study_session_notifier.dart';
import '../widgets/session_summary_card.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key});

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(studySessionProvider);
    final theme = Theme.of(context);
    final minutes = (session.durationSeconds / 60).ceil();
    final correctRate = (session.correctRate * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习总结'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResult(
              totalWords: session.totalReviewed,
              newWords: session.newWordsCount,
              correctRate: correctRate,
              minutes: minutes,
            ),
            tooltip: '分享',
          ),
        ],
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

extension _SessionSummaryScreenStateShare on _SessionSummaryScreenState {
  Future<void> _shareResult({
    required int totalWords,
    required int newWords,
    required int correctRate,
    required int minutes,
  }) async {
    // Generate screenshot from the SessionSummaryCard widget
    final Uint8List? imageBytes =
        await _screenshotController.captureFromLongWidget(
      SessionSummaryCard(
        totalWords: totalWords,
        newWords: newWords,
        correctRate: correctRate,
        minutes: minutes,
      ),
      delay: const Duration(milliseconds: 100),
    );

    if (imageBytes == null) return;

    // Save to temp file for sharing
    final tempDir = Directory.systemTemp;
    final file = File(p.join(tempDir.path, 'wordmaster_session.png'));
    await file.writeAsBytes(imageBytes);

    // Show dialog with image preview
    if (mounted) {
      await _showShareDialog(imageBytes, file);
    }
  }

  Future<void> _showShareDialog(Uint8List imageBytes, File file) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.share, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      '分享学习成果',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // Image preview
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _copyToClipboard(imageBytes);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制图片'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _shareFile(file);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('分享'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(Uint8List imageBytes) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此平台不支持复制图片到剪贴板')),
        );
      }
      return;
    }

    final item = DataWriterItem();
    item.add(Formats.png(imageBytes));
    await clipboard.write([item]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片已复制到剪贴板，可直接粘贴'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _shareFile(File file) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop: show file path
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片已保存到: ${file.path}')),
        );
      }
    } else {
      // Mobile: share via system share sheet
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'WordMaster 学习打卡',
        ),
      );
    }
  }
}
