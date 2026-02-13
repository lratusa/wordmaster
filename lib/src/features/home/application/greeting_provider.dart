import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Time periods for greeting selection
enum TimePeriod {
  lateNight, // 0-6
  morning, // 6-12
  noon, // 12-14
  afternoon, // 14-18
  evening, // 18-24
}

/// Greeting data with icon and message
class GreetingData {
  final String greeting;
  final String icon;
  final String encouragement;

  const GreetingData({
    required this.greeting,
    required this.icon,
    required this.encouragement,
  });
}

/// Greeting message pools for each time period
const _greetingPools = <TimePeriod, List<String>>{
  TimePeriod.lateNight: [
    '夜深了，注意休息',
    '夜猫子也要照顾好自己',
    '深夜学习，记得早点休息',
    '安静的夜晚，适合思考',
    '夜已深，别太累了',
    '星光作伴，继续前行',
    '夜深人静，正好学习',
    '熬夜伤身，早点休息吧',
  ],
  TimePeriod.morning: [
    '早上好',
    '新的一天，新的开始',
    '清晨的时光最珍贵',
    '美好的早晨',
    '早起的鸟儿有虫吃',
    '朝气蓬勃的一天',
    '早安，今天也要加油',
    '新的一天，新的收获',
    '清晨最适合背单词',
    '美好的一天从学习开始',
  ],
  TimePeriod.noon: [
    '中午好',
    '午间休息，充充电',
    '中午时光',
    '午后的阳光正好',
    '午餐后来几个单词',
    '中场休息，补充能量',
    '午安，记得劳逸结合',
    '阳光正好，心情正佳',
  ],
  TimePeriod.afternoon: [
    '下午好',
    '下午茶时间到了',
    '继续加油',
    '下午的学习效率更高',
    '美好的午后时光',
    '下午也要保持专注',
    '喝杯茶，继续学习',
    '午后时光，静心充电',
    '下午好，保持状态',
    '阳光渐斜，收获满满',
  ],
  TimePeriod.evening: [
    '晚上好',
    '夜晚学习，效率更高',
    '安静的夜晚',
    '忙碌了一天，辛苦了',
    '晚间时光，静心学习',
    '夜幕降临，继续努力',
    '晚安前再学几个词',
    '一天结束，收获如何',
    '夜色温柔，学习正好',
    '今天也辛苦了',
  ],
};

/// Time-based icons
const _timeIcons = <TimePeriod, String>{
  TimePeriod.lateNight: '🌙',
  TimePeriod.morning: '☀️',
  TimePeriod.noon: '🌤️',
  TimePeriod.afternoon: '🌅',
  TimePeriod.evening: '🌆',
};

/// Encouragement templates based on learning context
/// Templates with {placeholders} will be formatted with actual data
const _encouragementTemplates = [
  '已连续学习 {streak} 天，继续保持！',
  '今天已学 {todayWords} 个词，真棒！',
  '已掌握 {totalWords} 个单词！',
  '每天进步一点点，积少成多！',
  '坚持就是胜利！',
  '学习使你更强大！',
  '今天也要加油哦！',
  '词汇量就是你的超能力！',
  '每个单词都是一块砖，筑起知识的高墙',
  '量变引起质变，继续积累！',
  '你比昨天的自己更强了',
  '学习是最好的投资',
  '今天的努力，明天的收获',
  '一步一个脚印，稳步前进',
  '知识改变命运，加油！',
  '你的坚持终将得到回报',
  '累计 {totalWords} 词，词汇大师就是你！',
  '连续 {streak} 天打卡，太厉害了！',
  '今日 {todayWords} 词已入账！',
];

/// Templates shown when daily goal is not yet reached
const _goalPendingTemplates = [
  '距离今日目标还差 {remaining} 个词',
  '再学 {remaining} 个词就完成今日目标啦！',
  '加油！还有 {remaining} 个词达成目标',
  '今日目标近在咫尺，还差 {remaining} 个',
  '冲刺！{remaining} 个词后完成任务',
  '胜利在望，仅剩 {remaining} 个词',
  '离目标只差 {remaining} 步了',
  '最后 {remaining} 个词，你可以的！',
];

/// Templates shown when daily goal is achieved
const _goalAchievedTemplates = [
  '今日目标已达成，太棒了！',
  '完成今日目标，给自己点个赞！',
  '目标达成！继续保持这份热情！',
  '今天的任务完成了，真厉害！',
  '恭喜完成今日目标！',
  '目标达成，你真的很棒！',
  '今日份的努力已签收！',
  '完美完成今天的学习计划！',
  '今日目标✓，明天继续！',
  '又是收获满满的一天！',
  '今天的你超级优秀！',
  '学习达人就是你！',
];

/// Provider for greeting data
class GreetingNotifier extends Notifier<GreetingData> {
  @override
  GreetingData build() {
    return _generateGreeting();
  }

  GreetingData _generateGreeting() {
    final now = DateTime.now();
    final period = _getTimePeriod(now.hour);
    final dayOfYear = _getDayOfYear(now);

    // Use day of year as seed for daily variation
    final greetings = _greetingPools[period]!;
    final greetingIndex = dayOfYear % greetings.length;

    return GreetingData(
      greeting: greetings[greetingIndex],
      icon: _timeIcons[period]!,
      // encouragement is computed dynamically based on context
      encouragement: '',
    );
  }

  TimePeriod _getTimePeriod(int hour) {
    if (hour < 6) return TimePeriod.lateNight;
    if (hour < 12) return TimePeriod.morning;
    if (hour < 14) return TimePeriod.noon;
    if (hour < 18) return TimePeriod.afternoon;
    return TimePeriod.evening;
  }

  int _getDayOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    return date.difference(firstDayOfYear).inDays + 1;
  }

  /// Generate encouragement message based on learning context
  String formatEncouragement(
    String _, {
    int streak = 0,
    int todayWords = 0,
    int totalWords = 0,
    int dailyGoal = 10,
  }) {
    final now = DateTime.now();
    final dayOfYear = _getDayOfYear(now);
    final remaining = dailyGoal - todayWords;
    final goalAchieved = remaining <= 0;

    // Use day of year to determine message category (goal vs general)
    // Alternate between goal-related and general messages
    final showGoalMessage = dayOfYear % 2 == 0;

    String template;
    if (showGoalMessage) {
      if (goalAchieved) {
        final index = dayOfYear % _goalAchievedTemplates.length;
        template = _goalAchievedTemplates[index];
      } else {
        final index = dayOfYear % _goalPendingTemplates.length;
        template = _goalPendingTemplates[index];
      }
    } else {
      final index = dayOfYear % _encouragementTemplates.length;
      template = _encouragementTemplates[index];
    }

    return template
        .replaceAll('{streak}', streak.toString())
        .replaceAll('{todayWords}', todayWords.toString())
        .replaceAll('{totalWords}', totalWords.toString())
        .replaceAll('{remaining}', remaining.toString());
  }

  /// Refresh greeting (e.g., when time period changes)
  void refresh() {
    state = _generateGreeting();
  }
}

final greetingProvider =
    NotifierProvider<GreetingNotifier, GreetingData>(GreetingNotifier.new);
