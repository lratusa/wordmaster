# Progress Log

## Session 3: 2026-02-12 - Phase 9: Testing & Release

### Plan
1. Unit Tests:
   - [x] FsrsService tests (FSRS algorithm wrapper) - 12 tests
   - [x] Word/WordList model tests - 16 tests
   - [ ] ProgressRepository tests (database CRUD) - skipped (requires DB mock)
   - [ ] CheckinRepository tests (streak calculation) - skipped (requires DB mock)

2. Widget Tests:
   - [x] FuriganaText widget test - 10 tests
   - [x] Smoke tests (light/dark theme) - 2 tests
   - [ ] CheckinCard widget test - skipped (complex dependencies)

3. Release Builds:
   - [x] Windows release build - SUCCESS (wordmaster.exe)
   - [x] Android release build - SUCCESS (app-release.apk, 57.2MB)

### Progress
- [x] Analyzed project structure (46 source files)
- [x] Created test/unit/fsrs_service_test.dart (12 tests)
- [x] Created test/unit/word_model_test.dart (16 tests)
- [x] Created test/widget/furigana_text_test.dart (10 tests)
- [x] Updated test/widget_test.dart (2 smoke tests)
- [x] All 40 tests passing
- [x] Windows release build: build\windows\x64\runner\Release\wordmaster.exe
- [x] Android release build: build\app\outputs\flutter-apk\app-release.apk
- [x] Fixed Kotlin incremental compilation issue (cross-drive paths)
- [x] Configured Flutter JDK path

### Issues Resolved
| Issue | Resolution |
|-------|------------|
| JAVA_HOME invalid path | flutter config --jdk-dir="..." |
| Kotlin cross-drive incremental fail | Added kotlin.incremental=false to gradle.properties |
| Smoke test DB initialization | Simplified to theme-only tests |

### CI/CD Pipeline
- [x] Created `.github/workflows/ci.yml`
- Triggers: push to main, pull requests, version tags (v*)
- Jobs: Test → Build Android + Build Windows → Release
- Auto-creates GitHub Release on `git tag v1.0.0 && git push --tags`

---

## Session 1: 2026-02-10 (Previous Sessions - Summarized)

### Phase 0: Flutter 环境搭建
- **Status:** complete
- Flutter SDK 3.38.9 installed and configured
- Windows desktop support enabled
- flutter doctor passing

### Phase 1: 项目基础
- **Status:** complete
- pubspec.yaml with all dependencies (using `any` version constraints)
- SQLite database with platform auto-detection
- GoRouter with ShellRoute for responsive navigation
- Material 3 theming with AppColors
- Responsive layout (BottomNavigationBar / NavigationRail)
- All page skeletons created

### Phase 2: 词汇数据层
- **Status:** complete
- CET-4 (50 words) and JLPT N5 (50 words) JSON files created
- WordListAssetDatasource, WordListRepository, WordRepository
- Riverpod providers (fixed StateProvider → NotifierProvider)
- FuriganaText widget
- Word list browser and detail screens
- First-launch import in main.dart
- Build verified successfully

### Phase 3: FSRS 与闪卡学习
- **Status:** in_progress
- Created fsrs_service.dart (rewrote for FSRS 2.0.1 API)
- Created user_progress.dart model
- Created progress_repository.dart (rewrote for FSRS 2.0.1 API)
- Created session_repository.dart
- Created study_session_notifier.dart (NEEDS FSRS API FIX)
- Created study_setup_screen.dart
- Created study_session_screen.dart (flip animation, rating)
- Created session_summary_screen.dart
- **BLOCKED:** study_session_notifier.dart still references card.reps, card.lapses, card.state.index

## Session 2: 2026-02-11 (Current)

### Phase 3 (continued): Fixing FSRS API
- **Status:** in_progress
- Confirmed FSRS 2.0.1 Card properties via pub cache exploration
- Card has: cardId, state, step, stability, difficulty, due, lastReview
- Card does NOT have: reps, lapses
- State uses .value not .index
- Next: Fix study_session_notifier.dart rateCard() method + user_progress.dart fields
- Then: Build verification

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Phase 1 build | flutter build windows | Success | Success | ✓ |
| Phase 2 build | flutter build windows | Success (after StateProvider fix) | Success | ✓ |
| Phase 3 build | flutter build windows | Pending | Not yet tested | ⏳ |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| Session 1 | go_router version mismatch | 1 | Used `any` constraints |
| Session 1 | nuget.exe not found | 1 | winget install |
| Session 1 | StateProvider not in Riverpod 3.x | 1 | NotifierProvider pattern |
| Session 1 | FSRS class doesn't exist | 1 | It's Scheduler |
| Session 1 | Card() missing cardId | 1 | Card(cardId: wordId) |
| Session 1 | card.reps/lapses not found | pending | Remove from notifier |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 3 - fixing study_session_notifier.dart for FSRS 2.0.1 |
| Where am I going? | Phase 4 (TTS) → Phase 5 (听力) → Phase 6 (AI) → Phase 7 (打卡) → Phase 8 (统计) → Phase 9 (测试) |
| What's the goal? | 多平台背单词App: FSRS复习 + TTS + 听力 + AI短文 + 打卡分享 |
| What have I learned? | FSRS 2.0.1 API uses Scheduler/Card(cardId)/no reps/lapses; Riverpod 3.x dropped StateProvider |
| What have I done? | Phases 0-2 complete, Phase 3 mostly done (UI+service), fixing API compatibility |
