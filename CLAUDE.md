# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run the app (auto-detects platform)
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d macos
flutter run -d linux
flutter run -d chrome    # Web (if enabled)

# Build for release
flutter build windows
flutter build apk
flutter build ios
flutter build macos
flutter build linux

# Run tests
flutter test
flutter test test/specific_test.dart    # Single test file

# Generate code (Riverpod generators, freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Analyze code
flutter analyze
```

## Architecture

### Feature-Based Structure

```
lib/
├── main.dart                 # App entry, DB init, window config
├── app.dart                  # MaterialApp with theme & router
└── src/
    ├── core/                 # Shared infrastructure
    │   ├── database/         # SQLite via sqflite_common_ffi
    │   ├── services/         # TTS (sherpa-onnx), AI services
    │   ├── routing/          # GoRouter with ShellRoute for nav
    │   └── theme/            # AppColors, AppTheme, AppSpacing
    ├── common_widgets/       # Shared widgets (FuriganaText, ResponsiveLayout)
    └── features/             # Each feature is self-contained
        ├── study/            # Flashcard learning with FSRS
        ├── audio_review/     # Listening practice mode
        ├── word_lists/       # Word list management & download
        ├── ai_passage/       # LLM-generated reading passages
        ├── checkin/          # Daily streaks & achievements
        ├── statistics/       # Learning analytics (fl_chart)
        ├── settings/         # App configuration
        └── home/             # Dashboard screen
```

### Feature Module Pattern

Each feature follows this structure:
- `domain/` - Models, enums, service interfaces
- `data/` - Repositories, data sources
- `application/` - Riverpod providers & notifiers
- `presentation/` - Screens and widgets

### Key Technical Decisions

**State Management**: Riverpod 3.x with `ConsumerWidget` / `ConsumerStatefulWidget`. Providers are defined in `application/` folders within features.

**Navigation**: GoRouter with a `ShellRoute` that provides a responsive app shell (`NavigationBar` on mobile, `NavigationRail` on desktop). Routes defined in `core/routing/app_router.dart`.

**Database**: SQLite via `sqflite_common_ffi` for desktop support. Single `DatabaseHelper` singleton. Schema in `core/database/database_tables.dart`. Foreign keys enabled with CASCADE deletes.

**Spaced Repetition**: FSRS 2.0 algorithm via `fsrs` package. Cards serialized as JSON in `user_progress.fsrs_card_json`. Rating scale: 1 (Again) to 4 (Easy).

**TTS**: Dual system - sherpa-onnx for offline neural TTS (English/Chinese) + flutter_tts for system voices (Japanese fallback). Models downloaded to `{documents}/tts_models/`.

**AI Services**: Pluggable backends in `core/services/ai/` - OpenAI, DeepSeek, Ollama. All implement `AiService` abstract class.

### Database Schema (Key Tables)

- `word_lists` → `words` → `example_sentences` (cascade delete)
- `user_progress` - FSRS card state per word
- `review_sessions` → `review_logs` - Study session history
- `daily_checkins` - Streak tracking
- `generated_passages` - AI-generated reading content

### Platform Considerations

Desktop (Windows/macOS/Linux):
- Uses `sqflite_common_ffi` - initialized in `main.dart`
- Window management via `window_manager` package
- Shows `NavigationRail` instead of bottom nav

Mobile (Android/iOS):
- Standard sqflite
- Shows `NavigationBar` at bottom

## UI Conventions

**Colors**: Use `AppColors` from `core/theme/app_colors.dart`. Use `primaryDark` for text (better contrast than `primary`).

**Spacing**: Use `AppSpacing` constants from `core/theme/app_spacing.dart`.

**Dark Mode**: Check `Theme.of(context).brightness == Brightness.dark` for conditional styling.

**Language Support**: The app supports English (`en`) and Japanese (`ja`). Check `Language` enum in `word_lists/domain/enums/language.dart`.

## Word List Data

Built-in word lists are JSON files in `assets/wordlists/{english,japanese}/`. Additional lists downloaded from GitHub to `{app_docs}/wordlist_cache/`. Use `WordListDownloader` for remote lists.
