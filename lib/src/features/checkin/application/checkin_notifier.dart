import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../study/data/repositories/session_repository.dart';
import '../data/repositories/checkin_repository.dart';

class CheckinState {
  final bool isLoading;
  final bool hasCheckedIn;
  final CheckinRecord? record;
  final List<Achievement> achievements;
  final int totalWordsLearned;
  final int totalStudyDays;
  final int streakDays;
  final String? error;

  // Today's stats from sessions
  final int todayNewWords;
  final int todayReviewWords;
  final int todayCorrectCount;
  final int todayMinutes;

  const CheckinState({
    this.isLoading = true,
    this.hasCheckedIn = false,
    this.record,
    this.achievements = const [],
    this.totalWordsLearned = 0,
    this.totalStudyDays = 0,
    this.streakDays = 0,
    this.error,
    this.todayNewWords = 0,
    this.todayReviewWords = 0,
    this.todayCorrectCount = 0,
    this.todayMinutes = 0,
  });

  CheckinState copyWith({
    bool? isLoading,
    bool? hasCheckedIn,
    CheckinRecord? record,
    List<Achievement>? achievements,
    int? totalWordsLearned,
    int? totalStudyDays,
    int? streakDays,
    String? error,
    int? todayNewWords,
    int? todayReviewWords,
    int? todayCorrectCount,
    int? todayMinutes,
  }) {
    return CheckinState(
      isLoading: isLoading ?? this.isLoading,
      hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
      record: record ?? this.record,
      achievements: achievements ?? this.achievements,
      totalWordsLearned: totalWordsLearned ?? this.totalWordsLearned,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      streakDays: streakDays ?? this.streakDays,
      error: error,
      todayNewWords: todayNewWords ?? this.todayNewWords,
      todayReviewWords: todayReviewWords ?? this.todayReviewWords,
      todayCorrectCount: todayCorrectCount ?? this.todayCorrectCount,
      todayMinutes: todayMinutes ?? this.todayMinutes,
    );
  }

  double get todayCorrectRate {
    final total = todayNewWords + todayReviewWords;
    return total > 0 ? todayCorrectCount / total : 0;
  }
}

class CheckinNotifier extends Notifier<CheckinState> {
  @override
  CheckinState build() {
    return const CheckinState();
  }

  final _checkinRepo = CheckinRepository();
  final _sessionRepo = SessionRepository();

  /// Load check-in data
  Future<void> loadData() async {
    state = const CheckinState(isLoading: true);

    try {
      final hasCheckedIn = await _checkinRepo.hasCheckedInToday();
      final record = await _checkinRepo.getTodayCheckin();
      final achievements = await _checkinRepo.getAchievements();
      final totalWords = await _checkinRepo.getTotalWordsLearned();
      final totalDays = await _checkinRepo.getTotalStudyDays();
      final streakDays = await _checkinRepo.getStreakDays();
      final todayStats = await _sessionRepo.getTodayStats();

      state = CheckinState(
        isLoading: false,
        hasCheckedIn: hasCheckedIn,
        record: record,
        achievements: achievements,
        totalWordsLearned: totalWords,
        totalStudyDays: totalDays,
        streakDays: streakDays,
        todayNewWords: todayStats.newWords,
        todayReviewWords: todayStats.reviewWords,
        todayCorrectCount: todayStats.correctCount,
        todayMinutes: todayStats.totalMinutes,
      );
    } catch (e) {
      state = CheckinState(isLoading: false, error: '加载失败: $e');
    }
  }

  /// Perform check-in
  Future<void> doCheckin() async {
    try {
      final todayStats = await _sessionRepo.getTodayStats();

      final record = await _checkinRepo.checkin(
        newWords: todayStats.newWords,
        reviewWords: todayStats.reviewWords,
        correctRate: (todayStats.newWords + todayStats.reviewWords) > 0
            ? todayStats.correctCount /
                (todayStats.newWords + todayStats.reviewWords)
            : 0,
        studyMinutes: todayStats.totalMinutes,
      );

      // Reload achievements
      final achievements = await _checkinRepo.getAchievements();
      final totalWords = await _checkinRepo.getTotalWordsLearned();
      final totalDays = await _checkinRepo.getTotalStudyDays();

      state = state.copyWith(
        hasCheckedIn: true,
        record: record,
        achievements: achievements,
        totalWordsLearned: totalWords,
        totalStudyDays: totalDays,
        streakDays: record.streakDays,
      );
    } catch (e) {
      state = state.copyWith(error: '打卡失败: $e');
    }
  }
}

final checkinProvider =
    NotifierProvider<CheckinNotifier, CheckinState>(CheckinNotifier.new);
