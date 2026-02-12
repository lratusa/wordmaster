class AppConstants {
  AppConstants._();

  static const String appName = 'WordMaster';
  static const String appTagline = '你的智能背单词伙伴';

  // Default study settings
  static const int defaultNewWordsPerDay = 10;
  static const int defaultReviewLimitPerDay = 200;
  static const double defaultDesiredRetention = 0.9;

  // Checkin defaults
  static const int defaultCheckinNewWordsGoal = 10;

  // Audio review
  static const double defaultTtsSpeed = 0.5;
  static const double slowTtsSpeed = 0.35;

  // AI passage
  static const int passageWordCountMin = 8;
  static const int passageWordCountMax = 12;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  // Desktop window
  static const double desktopMinWidth = 800;
  static const double desktopMinHeight = 600;
  static const double desktopDefaultWidth = 1200;
  static const double desktopDefaultHeight = 800;
}
