import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../checkin/data/repositories/checkin_repository.dart';
import '../../../study/data/repositories/session_repository.dart';

/// Providers for statistics data
final _weeklyStatsProvider = FutureProvider.autoDispose((ref) async {
  return SessionRepository().getDailyStats(7);
});

final _allTimeStatsProvider = FutureProvider.autoDispose((ref) async {
  return SessionRepository().getAllTimeStats();
});

final _checkinHistoryProvider = FutureProvider.autoDispose((ref) async {
  return CheckinRepository().getCheckinHistory(30);
});

final _totalWordsProvider = FutureProvider.autoDispose((ref) async {
  return CheckinRepository().getTotalWordsLearned();
});

final _streakProvider = FutureProvider.autoDispose((ref) async {
  return CheckinRepository().getStreakDays();
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyStats = ref.watch(_weeklyStatsProvider);
    final allTimeStats = ref.watch(_allTimeStatsProvider);
    final checkinHistory = ref.watch(_checkinHistoryProvider);
    final totalWords = ref.watch(_totalWordsProvider);
    final streak = ref.watch(_streakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview cards
            _buildOverviewCards(context, allTimeStats, totalWords, streak),
            const SizedBox(height: 20),

            // Weekly words chart
            _buildSectionTitle(context, '本周学习量'),
            const SizedBox(height: 12),
            _buildWeeklyWordsChart(context, weeklyStats),
            const SizedBox(height: 20),

            // Weekly study time chart
            _buildSectionTitle(context, '本周学习时长 (分钟)'),
            const SizedBox(height: 12),
            _buildWeeklyTimeChart(context, weeklyStats),
            const SizedBox(height: 20),

            // Checkin calendar heatmap
            _buildSectionTitle(context, '打卡记录 (近30天)'),
            const SizedBox(height: 12),
            _buildCheckinCalendar(context, checkinHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(
    BuildContext context,
    AsyncValue<({int totalSessions, int totalWords, int totalMinutes, double avgCorrectRate})>
        allTimeStats,
    AsyncValue<int> totalWords,
    AsyncValue<int> streak,
  ) {
    final stats = allTimeStats.value;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 120,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        final items = [
          (
            icon: Icons.local_fire_department,
            color: AppColors.streakFire,
            value: '${streak.value ?? 0}',
            label: '连续打卡',
            unit: '天',
          ),
          (
            icon: Icons.library_books,
            color: AppColors.primary,
            value: '${totalWords.value ?? 0}',
            label: '已掌握',
            unit: '词',
          ),
          (
            icon: Icons.timer,
            color: AppColors.info,
            value: '${stats?.totalMinutes ?? 0}',
            label: '总学习时长',
            unit: '分钟',
          ),
          (
            icon: Icons.check_circle,
            color: AppColors.success,
            value: '${((stats?.avgCorrectRate ?? 0) * 100).round()}%',
            label: '平均正确率',
            unit: '',
          ),
        ];
        final item = items[index];
        return _buildOverviewCard(
          context,
          icon: item.icon,
          color: item.color,
          value: item.value,
          label: item.label,
          unit: item.unit,
        );
      },
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required String unit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    ' $unit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildWeeklyWordsChart(
    BuildContext context,
    AsyncValue<List<({String date, int newWords, int reviewWords, int correctCount, int totalSeconds})>>
        weeklyStats,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: weeklyStats.when(
            data: (data) => _buildWordsBarChart(context, data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildWordsBarChart(
    BuildContext context,
    List<({String date, int newWords, int reviewWords, int correctCount, int totalSeconds})> data,
  ) {
    // Build 7-day slots
    final slots = _buildWeekSlots(data);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(slots.map((s) => (s.newWords + s.reviewWords).toDouble()).toList()),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? '新词' : '复习';
              return BarTooltipItem(
                '$label: ${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= slots.length || value != idx.toDouble()) {
                  return const SizedBox.shrink();
                }
                final weekday = _shortWeekday(slots[idx].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(weekday, style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: slots.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.newWords.toDouble(),
                color: AppColors.primary,
                width: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: s.reviewWords.toDouble(),
                color: AppColors.accent,
                width: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyTimeChart(
    BuildContext context,
    AsyncValue<List<({String date, int newWords, int reviewWords, int correctCount, int totalSeconds})>>
        weeklyStats,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: weeklyStats.when(
            data: (data) => _buildTimeLineChart(context, data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLineChart(
    BuildContext context,
    List<({String date, int newWords, int reviewWords, int correctCount, int totalSeconds})> data,
  ) {
    final slots = _buildWeekSlots(data);
    final maxMinutes = _getMaxY(slots.map((s) => (s.totalSeconds / 60).ceilToDouble()).toList());

    return LineChart(
      LineChartData(
        maxY: maxMinutes,
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()} 分钟',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= slots.length || value != idx.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_shortWeekday(slots[idx].date), style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: slots.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                (entry.value.totalSeconds / 60).ceilToDouble(),
              );
            }).toList(),
            isCurved: true,
            color: AppColors.info,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.info.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinCalendar(
    BuildContext context,
    AsyncValue<List<CheckinRecord>> checkinHistory,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: checkinHistory.when(
          data: (records) => _buildCalendarGrid(context, records),
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, List<CheckinRecord> records) {
    final checkinDates = {for (final r in records) r.checkinDate};
    final today = DateTime.now();
    final days = <DateTime>[];

    // Build the last 30 days
    for (int i = 29; i >= 0; i--) {
      days.add(today.subtract(Duration(days: i)));
    }

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            const Text('已打卡', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            const Text('未打卡', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        // Grid
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: days.map((day) {
            final dateStr = day.toIso8601String().substring(0, 10);
            final isCheckedIn = checkinDates.contains(dateStr);
            final isToday = dateStr == today.toIso8601String().substring(0, 10);

            return Tooltip(
              message: '${DateFormat('M/d').format(day)} ${isCheckedIn ? '已打卡' : '未打卡'}',
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? AppColors.success.withValues(alpha: 0.8)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: isToday
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isCheckedIn ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '本月已打卡 ${records.where((r) {
            final d = DateTime.tryParse(r.checkinDate);
            return d != null && d.month == today.month && d.year == today.year;
          }).length} 天',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  // Helper: fill 7-day slots (even if no data for that day)
  List<_DaySlot> _buildWeekSlots(
    List<({String date, int newWords, int reviewWords, int correctCount, int totalSeconds})> data,
  ) {
    final dataMap = {for (final d in data) d.date: d};
    final today = DateTime.now();
    final slots = <_DaySlot>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final dateStr = day.toIso8601String().substring(0, 10);
      final d = dataMap[dateStr];
      slots.add(_DaySlot(
        date: day,
        newWords: d?.newWords ?? 0,
        reviewWords: d?.reviewWords ?? 0,
        correctCount: d?.correctCount ?? 0,
        totalSeconds: d?.totalSeconds ?? 0,
      ));
    }
    return slots;
  }

  String _shortWeekday(DateTime date) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[date.weekday - 1];
  }

  double _getMaxY(List<double> values) {
    if (values.isEmpty) return 10;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    return maxVal < 5 ? 10 : (maxVal * 1.2).ceilToDouble();
  }
}

class _DaySlot {
  final DateTime date;
  final int newWords;
  final int reviewWords;
  final int correctCount;
  final int totalSeconds;

  const _DaySlot({
    required this.date,
    required this.newWords,
    required this.reviewWords,
    required this.correctCount,
    required this.totalSeconds,
  });
}
