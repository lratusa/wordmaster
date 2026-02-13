class DbConstants {
  DbConstants._();

  static const String databaseName = 'wordmaster.db';
  static const int databaseVersion = 4;

  // Table names
  static const String tableWordLists = 'word_lists';
  static const String tableWords = 'words';
  static const String tableExampleSentences = 'example_sentences';
  static const String tableUserProgress = 'user_progress';
  static const String tableReviewSessions = 'review_sessions';
  static const String tableReviewLogs = 'review_logs';
  static const String tableGeneratedPassages = 'generated_passages';
  static const String tableDailyCheckins = 'daily_checkins';
  static const String tableAchievements = 'achievements';
  static const String tableSettings = 'settings';
}
