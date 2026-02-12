class DatabaseTables {
  DatabaseTables._();

  static const String createWordLists = '''
    CREATE TABLE word_lists (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      name            TEXT NOT NULL,
      language        TEXT NOT NULL CHECK(language IN ('en', 'ja')),
      description     TEXT,
      type            TEXT NOT NULL DEFAULT 'built_in' CHECK(type IN ('built_in', 'custom')),
      word_count      INTEGER NOT NULL DEFAULT 0,
      icon_name       TEXT,
      created_at      TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const String createWords = '''
    CREATE TABLE words (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      word_list_id        INTEGER NOT NULL,
      language            TEXT NOT NULL CHECK(language IN ('en', 'ja')),
      word                TEXT NOT NULL,
      translation_cn      TEXT NOT NULL,
      part_of_speech      TEXT,
      difficulty_level    INTEGER DEFAULT 1,
      phonetic            TEXT,
      audio_url           TEXT,
      reading             TEXT,
      jlpt_level          TEXT,
      created_at          TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (word_list_id) REFERENCES word_lists(id) ON DELETE CASCADE
    )
  ''';

  static const String createExampleSentences = '''
    CREATE TABLE example_sentences (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id         INTEGER NOT NULL,
      sentence        TEXT NOT NULL,
      translation_cn  TEXT NOT NULL,
      sort_order      INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
    )
  ''';

  static const String createUserProgress = '''
    CREATE TABLE user_progress (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id             INTEGER NOT NULL UNIQUE,
      fsrs_card_json      TEXT NOT NULL,
      due_date            TEXT NOT NULL,
      stability           REAL NOT NULL DEFAULT 0,
      difficulty          REAL NOT NULL DEFAULT 0,
      state               INTEGER NOT NULL DEFAULT 0,
      reps                INTEGER NOT NULL DEFAULT 0,
      lapses              INTEGER NOT NULL DEFAULT 0,
      review_count        INTEGER NOT NULL DEFAULT 0,
      correct_count       INTEGER NOT NULL DEFAULT 0,
      last_reviewed_at    TEXT,
      is_starred          INTEGER NOT NULL DEFAULT 0,
      is_new              INTEGER NOT NULL DEFAULT 1,
      created_at          TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at          TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
    )
  ''';

  static const String createReviewSessions = '''
    CREATE TABLE review_sessions (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      session_date        TEXT NOT NULL,
      session_type        TEXT NOT NULL CHECK(session_type IN ('flashcard', 'audio', 'mixed')),
      language            TEXT,
      word_list_id        INTEGER,
      total_words         INTEGER NOT NULL DEFAULT 0,
      new_words           INTEGER NOT NULL DEFAULT 0,
      review_words        INTEGER NOT NULL DEFAULT 0,
      correct_count       INTEGER NOT NULL DEFAULT 0,
      incorrect_count     INTEGER NOT NULL DEFAULT 0,
      starred_count       INTEGER NOT NULL DEFAULT 0,
      duration_seconds    INTEGER NOT NULL DEFAULT 0,
      started_at          TEXT NOT NULL,
      completed_at        TEXT,
      FOREIGN KEY (word_list_id) REFERENCES word_lists(id) ON DELETE SET NULL
    )
  ''';

  static const String createReviewLogs = '''
    CREATE TABLE review_logs (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id          INTEGER NOT NULL,
      word_id             INTEGER NOT NULL,
      rating              INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 4),
      response_time_ms    INTEGER,
      reviewed_at         TEXT NOT NULL DEFAULT (datetime('now')),
      fsrs_review_log_json TEXT,
      FOREIGN KEY (session_id) REFERENCES review_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
    )
  ''';

  static const String createGeneratedPassages = '''
    CREATE TABLE generated_passages (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      generation_date     TEXT NOT NULL,
      language            TEXT NOT NULL CHECK(language IN ('en', 'ja')),
      passage_text        TEXT NOT NULL,
      passage_translation TEXT,
      questions_json      TEXT NOT NULL,
      source_word_ids     TEXT NOT NULL,
      new_word_ids        TEXT,
      incorrect_word_ids  TEXT,
      starred_word_ids    TEXT,
      user_answers_json   TEXT,
      score               INTEGER,
      created_at          TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const String createDailyCheckins = '''
    CREATE TABLE daily_checkins (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      checkin_date    TEXT NOT NULL UNIQUE,
      new_words       INTEGER NOT NULL,
      review_words    INTEGER NOT NULL,
      correct_rate    REAL NOT NULL,
      study_minutes   INTEGER NOT NULL,
      streak_days     INTEGER NOT NULL,
      achievements    TEXT,
      created_at      TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';

  static const String createAchievements = '''
    CREATE TABLE achievements (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      achievement_key TEXT NOT NULL UNIQUE,
      name            TEXT NOT NULL,
      description     TEXT,
      icon_name       TEXT NOT NULL,
      unlocked_at     TEXT,
      progress        INTEGER DEFAULT 0,
      target          INTEGER NOT NULL
    )
  ''';

  static const String createSettings = '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  // Indexes
  static const List<String> createIndexes = [
    'CREATE INDEX idx_words_word_list ON words(word_list_id)',
    'CREATE INDEX idx_words_language ON words(language)',
    'CREATE INDEX idx_user_progress_due_date ON user_progress(due_date)',
    'CREATE INDEX idx_user_progress_state ON user_progress(state)',
    'CREATE INDEX idx_user_progress_is_starred ON user_progress(is_starred)',
    'CREATE INDEX idx_user_progress_is_new ON user_progress(is_new)',
    'CREATE INDEX idx_review_sessions_date ON review_sessions(session_date)',
    'CREATE INDEX idx_review_logs_session ON review_logs(session_id)',
    'CREATE INDEX idx_review_logs_word ON review_logs(word_id)',
    'CREATE INDEX idx_generated_passages_date ON generated_passages(generation_date)',
    'CREATE INDEX idx_example_sentences_word ON example_sentences(word_id)',
    'CREATE INDEX idx_daily_checkins_date ON daily_checkins(checkin_date)',
  ];

  static List<String> get allCreateStatements => [
    createWordLists,
    createWords,
    createExampleSentences,
    createUserProgress,
    createReviewSessions,
    createReviewLogs,
    createGeneratedPassages,
    createDailyCheckins,
    createAchievements,
    createSettings,
  ];
}
