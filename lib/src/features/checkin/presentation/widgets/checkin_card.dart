import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/checkin_repository.dart';

/// Widget designed to be rendered as a shareable screenshot image.
class CheckinCard extends StatelessWidget {
  final CheckinRecord record;
  final List<Achievement> achievements;
  final int totalWordsLearned;
  final int totalStudyDays;

  const CheckinCard({
    super.key,
    required this.record,
    required this.achievements,
    required this.totalWordsLearned,
    required this.totalStudyDays,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy年M月d日').format(DateTime.now());

    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90D9), Color(0xFF357ABD)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App branding
          const Icon(Icons.school, size: 40, color: Colors.white),
          const SizedBox(height: 8),
          const Text(
            'WordMaster',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '智能背单词',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Divider
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 24),

          // Date
          Text(
            dateStr,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),

          // Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.orangeAccent, size: 28),
              const SizedBox(width: 8),
              Text(
                '连续打卡 ${record.streakDays} 天',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  '今日成绩',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildStat(
                            '新学', '${record.newWords} 个')),
                    Expanded(
                        child: _buildStat(
                            '复习', '${record.reviewWords} 个')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _buildStat(
                            '正确率',
                            '${(record.correctRate * 100).round()}%')),
                    Expanded(
                        child: _buildStat(
                            '时长', '${record.studyMinutes} 分钟')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Achievements
          if (achievements.isNotEmpty) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: achievements.map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    a.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Cumulative stats
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '已掌握 $totalWordsLearned 词',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Text('  |  ',
                  style: TextStyle(color: Colors.white38)),
              Text(
                '学习 $totalStudyDays 天',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // App promotion
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'WordMaster - 你的智能背单词伙伴',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'AI驱动 | 艾宾浩斯记忆 | 英日双语',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
