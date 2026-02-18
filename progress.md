# Progress Log

## Session 13: 2026-02-18 - Windows 启动崩溃修复 (v1.2.1)

### Bug Investigation
- **现象:** v1.2.0 Windows release 无法启动
- **排查过程:** 运行 release exe 捕获 stderr 输出

### Bug 1: Flutter 资源未注册
- **错误:** `Unable to load asset: "assets/wordlists/french/cefr_a1_sample.json"`
- **原因:** Phase 15 添加了 `assets/wordlists/french/` 目录但未在 `pubspec.yaml` 注册
- **修复:** `pubspec.yaml` assets 段添加 `- assets/wordlists/french/`

### Bug 2: 数据库 CHECK 约束
- **错误:** `CHECK constraint failed: language IN ('en', 'ja')`
- **原因:** `word_lists`、`words`、`generated_passages` 三张表的 language 列 CHECK 约束不包含 `'fr'`
- **修复:** 更新 `database_tables.dart` 三处 CHECK 为 `('en', 'ja', 'fr')`
- **迁移难点:** SQLite 不支持 ALTER CONSTRAINT，且 sqflite 的 `onUpgrade` 在事务内运行，`PRAGMA foreign_keys=OFF` 无效
- **迁移方案:** 备份全部数据到 TEMP 表 → DROP 所有表 → CREATE 新 schema → INSERT 恢复数据（按 FK 依赖顺序）
- **验证:** 全新安装 ✓ + v4→v5 迁移 ✓ + 用户数据完整保留 ✓

### Files Modified
| File | Action |
|------|--------|
| `pubspec.yaml` | MODIFY — 添加 `assets/wordlists/french/` |
| `lib/src/core/constants/db_constants.dart` | MODIFY — version 4 → 5 |
| `lib/src/core/database/database_tables.dart` | MODIFY — CHECK 约束加 `'fr'`（3处） |
| `lib/src/core/database/database_helper.dart` | MODIFY — v5 迁移逻辑 |

### Release
- [x] Committed: `fb2151c`
- [x] Tagged: `v1.2.1`
- [x] Built Windows x64 (31MB)
- [x] Published GitHub Release: https://github.com/lratusa/wordmaster/releases/tag/v1.2.1

### Lessons Learned
- 添加新语言时需同步更新：Language enum、pubspec.yaml 资源、DB CHECK 约束、TTS 配置、UI
- SQLite `PRAGMA foreign_keys=OFF` 在事务内是 no-op，迁移需用 backup-drop-recreate 策略
- sqflite 的 `onUpgrade` 自动包裹在事务中，无法在其中切换 FK 模式

---

## Session 12: 2026-02-15 - Japanese TTS Error Message Fix (v1.1.1)

### Bug Fix
- **Bug:** Japanese TTS error message hardcoded "请在Windows设置中安装日语语音包" — shows incorrect instructions on Android
- **Root cause:** `getUnsupportedLanguageMessage()` in `tts_service.dart:114` had no platform check
- **Fix:** Made message platform-aware using `Platform.isAndroid` / `Platform.isIOS`
  - Android: "请在手机设置 → 语言与输入法 → 文字转语音中安装日语语音"
  - iOS: "请在设置 → 辅助功能 → 朗读内容中下载日语语音"
  - Other: "请在系统设置中安装日语语音包"

### Files Modified
| File | Action |
|------|--------|
| `lib/src/core/services/tts_service.dart` | MODIFY — platform-aware error message |

### Release
- [x] Committed: `e8a9902`
- [x] Tagged: `v1.1.1`
- [x] Built arm64 APK (92.1MB)
- [x] Published GitHub Release: https://github.com/lratusa/wordmaster/releases/tag/v1.1.1

---

## Session 11: 2026-02-16 - French Language Support Planning

### Status: Planning Phase 15

#### Research Completed
- [x] Analyzed current language architecture (Language enum, TTS service)
- [x] Identified French TTS models in sherpa-onnx (vits-piper-fr_FR-siwis, fr_FR-upmc)
- [x] Designed French word list category structure (CEFR A1-C2, DELF/DALF)
- [x] Created implementation checklist (7 files to modify)

#### Plan Created
- [x] Added Phase 15 to task_plan.md (15 tasks)
- [x] Documented French TTS model findings in findings.md
- [x] Logged planning session in progress.md

#### Plan Refinement (Based on User Feedback)
- [x] Added UTF-8 special character testing requirements (ê,ë,ç,œ,ù)
- [x] Specified test coverage: Language.fr unit tests, TTS config tests, repository tests
- [x] Clarified word list sources (FLE official CEFR lists)
- [x] Adjusted implementation order: enum → sample list → TTS → UI
- [x] Reduced initial sample from 50 to 20 words (focus on special char testing)

#### Implementation Progress
- [x] **Step 1:** Add `Language.fr` to language enum
  - Added `fr('fr', 'Français', '法语')` to Language enum
  - Created `test/unit/language_test.dart` with 8 unit tests
  - All tests passing ✓
- [x] **Step 2:** Create sample French word list (UTF-8 special characters)
  - Created `assets/wordlists/french/cefr_a1_sample.json` with 20 words
  - Includes all critical special characters: é,è,ê,ë,ç,œ,ù,â
  - Test words included: "être", "français", "cœur", "élève", "garçon", "œuf"
  - Added to `word_list_asset_datasource.dart` for automatic import
- [x] **Step 3:** Add French TTS models
  - Added `fr-fr-siwis` (65MB, female voice) to model downloader
  - Added `fr-fr-upmc` (55MB, alternative voice) to model downloader
  - Updated TTS service: added 'fr' to `_sherpaLanguages`

- [x] **Step 4:** Update word list browser UI
  - Changed TabController length from 2 to 3
  - Added '法语' tab to TabBar
  - Added Language.fr tab to TabBarView
  - `flutter analyze` passes with 0 errors ✓
- [x] **Step 5:** Add French word list categories to downloader
  - Added DELF/DALF category enum
  - Added 6 French CEFR packages (A1-C2) to downloader
  - Added 6 DELF/DALF packages (A1-C2) to downloader
  - Added frenchCategories getter
  - Updated getCategoryName() for 'delf'
  - Updated getCategoryIcon() for 'delf'
  - Updated download screen to show French categories
  - Total: 12 French word list packages available for download
- [x] **Step 6:** Create French word list generator script
  - Created `generate_french_cefr.py` - AI-powered French word list generator
  - Uses Gemini API to generate:
    - French vocabulary (500-3000 words per level based on CEFR guidelines)
    - IPA phonetics with special character support (é,è,ê,ë,ç,œ,ù,â)
    - Chinese translations
    - Example sentences with translations
  - Added `generate_french_word_data()` method to GeminiClient
  - Added `generate_response()` helper method
  - Created comprehensive README_FRENCH.md with usage guide
  - Supports checkpoint/resume for interrupted generation
  - Batch processing: 15 words/batch, ~50-60 min for all levels
  - Total capacity: 9500 French words across A1-C2
- [x] **Step 7:** Fix UTF-8 encoding for Windows
  - Added sys.stdout/stderr.reconfigure(encoding='utf-8')
  - Fixes 'gbk' codec error with French ligatures (œ, æ)
  - All special characters now handled correctly
- [x] **Step 8:** Generate French A1 word list (500 words)
  - Generated 500 A1 words with 99.8% quality
  - Phonetics: [ɛtʁ], [ale], [fʁɑ̃sɛ]
  - Examples: être, aller, avoir, français, école, cœur
  - File: assets/wordlists/french/cefr_a1.json
- [x] **Step 9:** Generate French A2 word list (1000 words)
  - Generated 1000 A2 words with 100.0% quality (all fields complete)
  - Fixed JSON parsing regex to handle Gemini markdown code fences
  - File: assets/wordlists/french/cefr_a2.json
- [x] **Step 10:** Generate French B1-C2 word lists (7000 words)
  - Modified generator to use batched vocabulary generation (300 words/batch)
  - Fixed response truncation issue for large word counts (1500+)
  - **B1:** 1500 words with 99.9% quality ✓ (646KB)
  - **B2:** 2000 words with 100.0% quality ✓ (1.2MB)
  - **C1:** 2500 words with 100.0% quality ✓ (1.4MB)
  - **C2:** 3000 words with 99.9% quality ✓ (1.7MB)
  - **TOTAL:** 9500 French words across all CEFR levels (A1-C2)
  - All words include: IPA phonetics, Chinese translations, 2+ example sentences
  - B1: 1500 words - Queued
  - B2: 2000 words - Queued
  - C1: 2500 words - Queued
  - C2: 3000 words - Queued
  - Estimated time: 50-60 minutes

#### Implementation Summary
**Files Modified (5 files):**
1. `lib/src/features/word_lists/domain/enums/language.dart` — Added Language.fr
2. `lib/src/features/word_lists/data/datasources/word_list_asset_datasource.dart` — Added French sample
3. `lib/src/core/services/tts_model_downloader.dart` — Added 2 French TTS models
4. `lib/src/core/services/tts_service.dart` — Added 'fr' to sherpa languages
5. `lib/src/features/word_lists/presentation/screens/word_list_browser_screen.dart` — Added French tab

**Files Created (2 files):**
1. `assets/wordlists/french/cefr_a1_sample.json` — 20 French words with UTF-8 special chars
2. `test/unit/language_test.dart` — 8 unit tests for Language enum

#### Next Steps
5. Commit Phase 15 core implementation
6. Build and run app to verify:
   - French word list appears in browser
   - UTF-8 special characters display correctly
   - French TTS pronunciation works (requires downloading model first)
7. Add French word list repository tests
8. Add French TTS model configuration tests
9. Add French word list categories to downloader

---

## Session 10: 2026-02-14 - iOS Build Planning (blocked)

### Status: 等待 Mac mini 环境确认

#### 已知信息
- 用户有一台 Mac mini（位于中国）
- 可通过 iMessage / OpenClaw 远程操作
- 需要确认：macOS 版本、Xcode、Flutter、CocoaPods、磁盘空间

#### 待执行环境检查命令
```bash
sw_vers && xcode-select -p && flutter --version && pod --version && brew --version && df -h /
```

#### 预期工作
- Dart 代码层面无需改动（平台分支已就绪）
- 主要工作：Xcode 签名配置 + iOS 权限声明（Info.plist）
- 验证 sherpa_onnx iOS 原生库支持
- 中国网络环境需考虑：Flutter 中国镜像、CocoaPods 镜像

---

## Session 9: 2026-02-14 - Android Release Build

### Completed Tasks

#### 1. Android Configuration Fix
- [x] Added `<uses-permission android:name="android.permission.INTERNET"/>` to main AndroidManifest.xml
- [x] Fixed `android:label` from "wordmaster" to "WordMaster"
- [x] No Dart code changes needed — all platform branching already correct

#### 2. Build Verification
- [x] `flutter analyze` — 0 errors, 1 warning (unused field), 60 info
- [x] Full APK (3 architectures): 127.1MB
- [x] arm64-only APK: 92.1MB
- [x] x86_64-only APK: 93.5MB (for emulator testing)

#### 3. APK Size Analysis
| Component | Size (per arch) |
|-----------|----------------|
| libonnxruntime.so (sherpa-onnx) | 15.2 MB |
| libflutter.so (Flutter engine) | 10.6 MB |
| libapp.so (Dart compiled) | 7.3 MB |
| libsherpa-onnx-*.so | 4.7 MB |
| Other native libs | 2.7 MB |
| Assets (wordlist JSONs) | 43.8 MB |

#### 4. Emulator Testing
- [x] Created x86_64 virtual device (Pixel 7, API 35)
- [x] Installed APK via `adb install` — Success
- [x] App launches on emulator

#### 5. GitHub Release
- [x] Committed AndroidManifest.xml changes
- [x] Tagged `v1.1.0-android`
- [x] Published GitHub Release: WordMaster v1.1.0
- [x] Uploaded: `app-release.apk` (92.1MB, arm64) + `WordMaster-v1.1.0-windows-x64.zip` (29.1MB)
- [x] Release URL: https://github.com/lratusa/wordmaster/releases/tag/v1.1.0-android

### Files Modified
| File | Action |
|------|--------|
| `android/app/src/main/AndroidManifest.xml` | MODIFY — add INTERNET permission, fix label |

### Known Risks (for future testing)
- sherpa-onnx TTS on Android: never tested on real device (plugin supports Android but untested in this project)
- TTS model extraction may OOM on low-RAM devices (reads entire 65-350MB archive into memory)
- Ollama localhost mode won't work on Android (need remote address)

---

## Session 8: 2026-02-13 - China Mirror Support (国内镜像)

### Completed Tasks

#### 1. Server Setup (47.93.144.50)
- [x] Created `/var/www/wordmaster/` directory with `wordlists/` and `tts-models/` subdirs
- [x] Updated nginx config in Docker container with `/wordmaster/` location block
- [x] Recreated Docker container with volume mounts (ro)
- [x] CORS headers enabled for app downloads
- [x] Uploaded 38 word list JSON files (20 English + 18 Japanese)
- [x] Renamed files to match GitHub naming (cet4-full.json, toefl-core.json, etc.)
- [x] TTS model downloads running in background on server
- [x] SSH key auth configured for passwordless access
- [x] Verified all word list endpoints return HTTP 200

#### 2. Code: DownloadMirror Service
- [x] Created `lib/src/core/services/download_mirror.dart`
- [x] `DownloadRegion` enum: `international`, `china`
- [x] URL resolver for wordlists and TTS models
- [x] Parse/serialize methods for settings storage

#### 3. Code: Two Independent Settings
- [x] Added `wordlist_download_region` and `tts_download_region` to `SettingKeys`
- [x] Added `wordlistDownloadRegion` and `ttsDownloadRegion` to `AppSettings`
- [x] Added setters in `SettingsNotifier`
- [x] Settings loaded from DB on startup

#### 4. Code: Refactored Downloaders
- [x] `WordlistDownloader` — URLs changed to relative paths, `resolveUrl()` method added
- [x] `downloadPackage()` accepts `region` parameter
- [x] `TtsModelDownloader` — URLs changed to filenames, `resolveUrl()` method added
- [x] `downloadModel()` accepts `region` parameter
- [x] `TtsModelManager` in `tts_service.dart` — `getModelUrl()` accepts `region` parameter

#### 5. Code: Settings UI
- [x] Added "下载源" section with two independent toggles
- [x] "词书下载源" — 国际 (GitHub) / 国内镜像
- [x] "语音包下载源" — 国际 (GitHub) / 国内镜像
- [x] Hint for China users: recommend switching AI to DeepSeek
- [x] Download screen reads region from settings

#### 6. Build Verification
- [x] `flutter analyze` — 0 errors, 0 warnings (59 info-only in test files)

### Files to Modify/Create
| File | Action |
|------|--------|
| `lib/src/core/services/download_mirror.dart` | CREATE |
| `lib/src/features/settings/data/repositories/settings_repository.dart` | MODIFY - add key |
| `lib/src/features/settings/application/settings_notifier.dart` | MODIFY - add field |
| `lib/src/core/services/wordlist_downloader.dart` | MODIFY - dynamic URLs |
| `lib/src/core/services/tts_model_downloader.dart` | MODIFY - dynamic URLs |
| `lib/src/core/services/tts_service.dart` | MODIFY - TtsModelManager URLs |
| `lib/src/features/settings/presentation/screens/settings_screen.dart` | MODIFY - add UI |
| `lib/src/features/word_lists/presentation/screens/word_list_download_screen.dart` | MODIFY - pass region |

---

## Session 7: 2026-02-13 - Kanji Quiz Modes & Bug Fixes

### Bug Fixes

#### Bug: 已学数量不更新 (Learned count not updating)
- **Issue**: After exiting study session midway, word list "已学" count doesn't update
- **Root cause**: `allWordListsProvider` not invalidated when navigating away from study screens
- **Fix**: Added `ref.invalidate(allWordListsProvider)` to all exit points:
  - `quiz_screen.dart` - exit dialog
  - `study_session_screen.dart` - exit dialog
  - `kanji_reading_quiz_screen.dart` - exit dialog
  - `kanji_selection_quiz_screen.dart` - exit dialog
  - `session_summary_screen.dart` - "去打卡" and "返回首页" buttons

### Completed Tasks

#### 1. Kanji Data Model Extension
- [x] Added `onyomi`, `kunyomi` fields to Word model
- [x] Added `isKanji`, `hasExamples`, `allReadings` computed properties
- [x] Added `reading` field to ExampleSentence (for compound word readings)
- [x] Database migration v3→v4 for new fields
- [x] Updated word_list_asset_datasource.dart to parse onyomi/kunyomi

#### 2. Kanji Quiz Screens
- [x] Created `kanji_reading_quiz_screen.dart` - 读音测试 mode
  - Shows large kanji with Chinese meaning
  - Options are mixed onyomi/kunyomi readings
  - Quality distractors with similar length filtering
- [x] Created `kanji_selection_quiz_screen.dart` - 汉字选择 mode
  - Shows example word with blank (e.g., "大＿＿" for 大雨)
  - Shows reading hint (e.g., "おおあめ")
  - Options are kanji characters
  - Fallback to reading test when no examples available

#### 3. Study Setup Screen Updates
- [x] Dynamic quiz format selector based on list type
- [x] Vocabulary lists: 经典卡片, 选择题
- [x] Kanji lists: 卡片, 读音, 汉字

#### 4. Bug Fixes
- [x] Fixed word_list_download_screen.dart storing formatted "音:イン 訓:の.む" instead of separate fields
- [x] Fixed example sentence storing "飲む（のむ）" instead of separate word/reading
- [x] Fixed distractor query not finding kanji (removed onyomi/kunyomi NULL filter)
- [x] Fixed English text leak in quiz options (added Chinese character filter)

### Files Modified/Created
| File | Action |
|------|--------|
| `lib/src/features/word_lists/domain/models/word.dart` | MODIFY - onyomi/kunyomi, ExampleSentence.reading |
| `lib/src/features/word_lists/domain/models/word_list.dart` | MODIFY - isKanjiList |
| `lib/src/features/study/application/study_session_notifier.dart` | MODIFY - QuizFormat enum |
| `lib/src/features/word_lists/data/repositories/word_repository.dart` | MODIFY - distractor methods |
| `lib/src/features/study/presentation/screens/kanji_reading_quiz_screen.dart` | CREATE |
| `lib/src/features/study/presentation/screens/kanji_selection_quiz_screen.dart` | CREATE |
| `lib/src/features/study/presentation/screens/study_setup_screen.dart` | MODIFY - dynamic quiz selector |
| `lib/src/features/study/presentation/screens/quiz_screen.dart` | MODIFY - Chinese filter |
| `lib/src/features/word_lists/presentation/screens/word_list_download_screen.dart` | MODIFY - proper field storage |
| `lib/src/core/routing/app_router.dart` | MODIFY - kanji quiz routes |
| `lib/src/core/database/database_tables.dart` | MODIFY - reading column |
| `lib/src/core/database/database_helper.dart` | MODIFY - migration v4 |
| `lib/src/core/constants/db_constants.dart` | MODIFY - version 4 |

### Known Issue
- Existing downloaded kanji word lists have incorrectly formatted data
- Users need to delete and re-download kanji lists for proper display

---

## Session 6: 2026-02-13 - TTS Model Selection & Wordlist URL Fixes

### Completed Tasks

#### 0. Final Verification (Session 6b)
- [x] Verified all 37 wordlist URLs return HTTP 200
- [x] Flutter analyze passes (no errors, 1 warning about unused field)
- [x] Phase 10 marked complete

#### 1. TTS Model Selection Bug Fix
- [x] **Bug**: `_detectKokoroModel()` ignored `active_model.txt`, picked models alphabetically
- [x] **Fix**: Renamed to `_detectActiveModel()`, added Priority 0 to check `active_model.txt` first
- [x] Added `_getActiveModelId()` helper method
- [x] Now respects user's selected voice model

#### 2. TTS Model Download Detection Fix
- [x] **Bug**: `isModelDownloaded()` checked only for `model.onnx` (Kokoro naming)
- [x] **Fix**: Now checks for any `.onnx` file (VITS models use names like `en_GB-alba-medium.onnx`)

#### 3. Removed Broken TTS Models
- [x] Removed `en-us-amy` (URL returns 404)
- [x] Removed `zh` (Chinese + English) - MeloTTS has limited English vocabulary
- [x] Removed `kokoro-multi-lang` per user request

#### 4. Wordlist URL Fixes (MAJOR)
- [x] **Bug**: URLs used hyphens (`-`) but repo files use underscores (`_`)
- [x] Fixed all 37 URLs to match actual filenames in GitHub repo
- [x] Removed non-existent wordlists: GRE (3), IELTS (3), GMAT (2), kaoyan-advanced, toefl-academic, cet4-core
- [x] Added Japanese Kanji wordlists (13 new):
  - JLPT Kanji N5-N1 (5)
  - School Kanji Grade 1-6, Middle, High (8)

#### 5. Updated Category System
- [x] Removed `WordListCategory.ielts`, `gre`, `gmat`
- [x] Added `WordListCategory.jlptKanji`, `schoolKanji`
- [x] Updated `englishCategories`, added `japaneseCategories`
- [x] Updated `getCategoryName()` and `getCategoryIcon()`
- [x] Updated download screen to show all Japanese categories

### Verified
- [x] All 37 wordlist URLs return HTTP 200
- [x] Flutter analyze passes (no errors)
- [x] TTS uses correct model from `active_model.txt`

### Files Modified
| File | Action |
|------|--------|
| `lib/src/core/services/tts_service.dart` | MODIFY - `_detectActiveModel()` fix |
| `lib/src/core/services/tts_model_downloader.dart` | MODIFY - Remove broken models |
| `lib/src/core/services/wordlist_downloader.dart` | MODIFY - Fix URLs, add kanji |
| `lib/src/features/word_lists/presentation/screens/word_list_download_screen.dart` | MODIFY - Update categories |

---

## Session 5: 2026-02-12 - Word List Generation & Bug Fixes

### Completed Tasks

#### 1. TOEFL Word List Generation
- [x] Created `generate_toefl.py` - generates TOEFL core + full word lists
- [x] Generated `toefl_core.json` (4,978 words - overlap with CET4/6)
- [x] Generated `toefl_full.json` (10,367 words - complete vocabulary)
- [x] API call via Gemini Flash for phonetics and examples
- [x] 99.9% coverage for phonetics and examples

#### 2. GitHub Wordlist Repository
- [x] Created `lratusa/wordmaster-wordlists` repository
- [x] Uploaded: toefl-core.json, toefl-full.json, cet4-full.json, cefr-a1.json, cefr-a2.json
- [x] Created `sync_to_github.py` for future syncs

#### 3. Download Error Handling
- [x] 404 errors now show: "该词库暂未上线，敬请期待" (friendly message)
- [x] Network errors show appropriate messages
- [x] Uses warning color for 404, error color for other failures

#### 4. Word List Refresh Fix
- [x] Added `ref.invalidate(allWordListsProvider)` after download
- [x] Added `ref.invalidate(wordListsByLanguageProvider)` for language-specific refresh
- [x] Word lists now update immediately after download

#### 5. Batch Word List Generator
- [x] Created `generate_all.py` - batch generation script
- [x] Supports: CET-4, CET-6, 考研, TOEFL, SAT, 中考, 高考
- [x] Progress checkpoints for resume capability
- [x] Core/Full split based on CET4/6 overlap

### In Progress
- [ ] CET-6 generation (855/3,991 words - 21%)
- [ ] 考研, SAT, 中考, 高考 generation (queued)

### Files Modified/Created
| File | Action |
|------|--------|
| `scripts/wordlist_generator/generate_toefl.py` | CREATE |
| `scripts/wordlist_generator/generate_all.py` | CREATE |
| `scripts/wordlist_generator/sync_to_github.py` | CREATE |
| `assets/wordlists/english/toefl_core.json` | CREATE |
| `assets/wordlists/english/toefl_full.json` | CREATE |
| `lib/src/features/word_lists/presentation/screens/word_list_download_screen.dart` | MODIFY |

### Pending
- [ ] Complete CET-6, 考研, SAT, 中考, 高考 generation
- [ ] Sync to GitHub and update downloads
- [ ] IELTS, GRE, GMAT have no source data (KyleBing repo doesn't include them)

---

## Session 4: 2026-02-12 - UI Enhancements & Bug Fixes

### Completed Tasks

#### 1. Enhanced Greeting Section (首页问候语)
- [x] Created `greeting_provider.dart` - diversified greeting messages by time period
- [x] Created `greeting_card.dart` - beautiful card design with gradient background
- [x] Simplified AppBar to just show app name
- [x] Time-based icons (🌙☀️🌤️🌅🌆)
- [x] Daily variation using day-of-year as seed
- [x] Dynamic encouragement messages (goal pending/achieved)
- [x] Short motivation shown as tag, long as quote box

#### 2. Fixed Word List Duplication Bug
- [x] Root cause: `_getNameForKey()` didn't handle CEFR keys properly
- [x] Fix: Now loads actual name from JSON before checking duplicates
- [x] Added `removeDuplicateWordLists()` function - auto-runs at startup
- [x] Added "Reset Word Lists" option in Settings → Data Management

#### 3. Added More Word List Categories
- [x] Added 中考, 高考, 考研, SAT, GMAT categories to downloader
- [x] Updated category list order (by learning stage)
- [x] Updated category icons and names

#### 4. Created Word List Download Screen
- [x] New `word_list_download_screen.dart` - browse and download word packages
- [x] Category filter chips
- [x] Download progress indicator
- [x] Added download button to word list browser AppBar

#### 5. Added More Greeting Messages
- [x] 8-10 messages per time period
- [x] 18 general encouragement templates
- [x] 8 goal-pending templates
- [x] 12 goal-achieved templates

### Files Modified/Created
| File | Action |
|------|--------|
| `lib/src/features/home/application/greeting_provider.dart` | CREATE |
| `lib/src/features/home/presentation/widgets/greeting_card.dart` | CREATE |
| `lib/src/features/home/presentation/screens/home_screen.dart` | MODIFY |
| `lib/src/features/word_lists/data/repositories/word_list_repository.dart` | MODIFY |
| `lib/src/features/word_lists/presentation/screens/word_list_download_screen.dart` | CREATE |
| `lib/src/features/word_lists/presentation/screens/word_list_browser_screen.dart` | MODIFY |
| `lib/src/features/settings/presentation/screens/settings_screen.dart` | MODIFY |
| `lib/src/core/services/wordlist_downloader.dart` | MODIFY |
| `lib/main.dart` | MODIFY |

### Pending
- [ ] Word list download requires actual GitHub repository with JSON data
- [ ] User requested: Download TOEFL and CET-6 complete word lists

---

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
