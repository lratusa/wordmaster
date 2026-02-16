# WordMaster 背单词 App - Task Plan

## Goal
构建一个多平台背单词应用（英语+日语），支持 FSRS 艾宾浩斯复习、TTS发音、听力训练、AI短文生成（可切换 OpenAI/DeepSeek/Ollama + 手动复制粘贴模式）、每日打卡截图分享。

## Current Phase
**Phase 15: French Language Support** — Add French as third supported language

### Phase 15: French Language Support (2026-02-16)
- [x] Add `Language.fr` to language enum with unit tests (8 tests passing)
- [x] Create sample French word list (20 words with special chars: ê,ë,ç,œ,ù)
  - Includes test words: "être", "français", "cœur", "élève", "garçon", "œuf"
  - UTF-8 encoding verified in JSON
- [x] Create `assets/wordlists/french/` directory
- [x] Add French TTS models to `tts_model_downloader.dart`
  - vits-piper-fr_FR-siwis-medium (~65MB)
  - vits-piper-fr_FR-upmc-medium (~55MB)
- [x] Update TTS service to support French (`_sherpaLanguages`)
- [x] Update word list browser UI to show French tab
- [x] `flutter analyze` verification (0 errors)
- [x] **Generate complete French CEFR word lists (A1-C2)**
  - A1: 500 words (100% quality, 186KB)
  - A2: 1000 words (100% quality, 394KB)
  - B1: 1500 words (99.9% quality, 646KB)
  - B2: 2000 words (100% quality, 1.2MB)
  - C1: 2500 words (100% quality, 1.4MB)
  - C2: 3000 words (99.9% quality, 1.7MB)
  - **Total: 9500 French words with IPA phonetics, Chinese translations, examples**
- [ ] **Critical: Test sherpa-onnx with French special characters**
  - Test TTS pronunciation of "être", "français", "cœur"
  - Verify UTF-8 handling in TTS input (requires running app)
- [ ] Add French TTS model configuration tests
- [ ] Add French wordlist download/parsing repository tests
- [x] Add French categories to `wordlist_downloader.dart` (12 packages: CEFR + DELF/DALF)
- [ ] Upload French TTS models to China mirror (47.93.144.50)
- **Implementation Order:** Language enum → Sample wordlist (special chars) → TTS config/test → UI → Word lists
- **Goal:** Enable French learning with UTF-8 special character support verified
- **Status:** nearly_complete — Core implementation + word lists complete, testing phase next

### Phase 14: iOS Release Build (pending)
- [ ] 确认 Mac mini 环境（macOS 版本、Xcode、Flutter、CocoaPods、磁盘空间）
- [ ] 安装缺失工具（Flutter SDK、Xcode、CocoaPods 等）
- [ ] 克隆仓库到 Mac mini（`git clone https://github.com/lratusa/wordmaster.git`）
- [ ] 检查 `ios/` 配置（Podfile、Info.plist 权限、签名）
- [ ] 添加 iOS 所需权限（网络、麦克风等）
- [ ] 验证 sherpa_onnx iOS 支持
- [ ] `flutter build ipa` 构建
- [ ] 真机测试（连接 iPhone）
- [ ] 发布（TestFlight 或直接安装）
- **前置条件:** Mac mini（macOS 13+）+ Xcode + Apple Developer 账号
- **阻塞原因:** 用户暂时无法操作 Mac mini，后续继续
- **Status:** blocked — 等待 Mac mini 环境确认

### Phase 13: Android Release Build (2026-02-14)
- [x] Add `INTERNET` permission to main `AndroidManifest.xml` (was only in debug/profile)
- [x] Fix app label: `wordmaster` → `WordMaster`
- [x] `flutter analyze` passes (0 errors, 1 warning, 60 info)
- [x] Build arm64 release APK (92.1MB)
- [x] Build x86_64 APK for emulator testing (93.5MB)
- [x] Test on Android emulator (x86_64, API 35) — app installs and launches
- [x] Publish to GitHub Release v1.1.0 (APK + Windows zip)
- **Zero Dart code changes** — only Android config files modified
- **Status:** complete

### Phase 12: China Mirror Support (国内镜像) (2026-02-13)
- [x] Create `DownloadMirror` service (`lib/src/core/services/download_mirror.dart`)
- [x] Add `wordlist_download_region` + `tts_download_region` setting keys (independent)
- [x] Add `wordlistDownloadRegion` + `ttsDownloadRegion` to `AppSettings` + `SettingsNotifier`
- [x] Refactor `WordlistDownloader` — relative paths + dynamic base URL via `DownloadMirror`
- [x] Refactor `TtsModelDownloader` — filename only + dynamic base URL via `DownloadMirror`
- [x] Refactor `TtsModelManager` in `tts_service.dart` — use dynamic mirror URL
- [x] Add "下载源" section to `SettingsScreen` with two independent region toggles
- [x] Add hint text when China region: recommend DeepSeek over OpenAI
- [x] Server setup: nginx + static files on 47.93.144.50 (Gitee rejected for RAW abuse)
- [x] Uploaded 38 word lists + TTS models downloading on server
- [x] `flutter analyze` passes (0 errors)
- **Status:** complete

#### Architecture Design

**New file: `lib/src/core/services/download_mirror.dart`**
```
enum DownloadRegion { international, china }

class DownloadMirror {
  // Wordlists — two independent settings
  international: https://raw.githubusercontent.com/lratusa/wordmaster-wordlists/main
  china:         http://47.93.144.50/wordmaster/wordlists

  // TTS Models — two independent settings
  international: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models
  china:         http://47.93.144.50/wordmaster/tts-models
}
```

**Two independent settings:**
- `wordlist_download_region` — controls word list download source
- `tts_download_region` — controls TTS model download source

**Affected files (8 files):**
1. `lib/src/core/services/download_mirror.dart` — CREATE
2. `lib/src/features/settings/data/repositories/settings_repository.dart` — ADD 2 keys
3. `lib/src/features/settings/application/settings_notifier.dart` — ADD 2 fields + setters
4. `lib/src/core/services/wordlist_downloader.dart` — REFACTOR URLs
5. `lib/src/core/services/tts_model_downloader.dart` — REFACTOR URLs
6. `lib/src/core/services/tts_service.dart` — REFACTOR TtsModelManager URLs
7. `lib/src/features/settings/presentation/screens/settings_screen.dart` — ADD UI section
8. `lib/src/features/word_lists/presentation/screens/word_list_download_screen.dart` — PASS region

**Key design decisions:**
- WordListPackage.url and TtsModel.url become relative paths; base URL resolved at download time
- DownloadMirror reads region from SettingsRepository (no Riverpod dependency — static + async)
- China mirror hosted on self-managed cloud server (47.93.144.50) — Gitee rejected for RAW abuse
- Two independent settings allow mixing sources (e.g., GitHub for wordlists, China for TTS)

### Phase 11: Kanji Quiz Modes (2026-02-13)
- [x] Added onyomi/kunyomi fields to Word model
- [x] Database migration v4 for example sentence reading field
- [x] isKanjiList property for WordList
- [x] Extended QuizFormat enum (kanjiReading, kanjiSelection)
- [x] KanjiReadingQuizScreen - show kanji, select reading
- [x] KanjiSelectionQuizScreen - show example with blank, select kanji
- [x] Quality distractors with similar length filtering
- [x] Fallback to reading test when no examples available
- [x] Fixed word_list_download_screen.dart to store onyomi/kunyomi separately
- [x] Fixed quiz distractor English text leak (Chinese character filter)
- **Status:** complete

### Phase 10: Bug Fixes & Maintenance (2026-02-13)
- [x] TTS model selection respects `active_model.txt`
- [x] TTS model download detection fixed (any .onnx file)
- [x] Wordlist URLs fixed to match actual repo filenames
- [x] Added 13 Japanese Kanji wordlists (JLPT + School)
- [x] Removed non-existent wordlists (GRE, IELTS, GMAT)
- [x] Verified all 37 wordlist URLs return HTTP 200
- **Status:** complete

## Phases

### Phase 0: Flutter 环境搭建
- [x] 安装 Flutter SDK 3.38.9
- [x] 启用 Windows 桌面支持
- [x] flutter doctor 通过
- **Status:** complete

### Phase 1: 项目基础
- [x] pubspec.yaml 全部依赖
- [x] SQLite 数据库 (自动适配移动/桌面)
- [x] GoRouter 路由 + ShellRoute 响应式导航
- [x] Material 3 主题 + 颜色系统
- [x] 响应式布局骨架 (手机底部导航 / 桌面侧边栏)
- [x] 所有页面骨架
- **Status:** complete

### Phase 2: 词汇数据层
- [x] CET-4 示例词单 (50词+例句) JSON
- [x] JLPT N5 示例词单 (50词+例句) JSON
- [x] WordListAssetDatasource - JSON 资源加载
- [x] WordListRepository - SQLite CRUD
- [x] WordRepository - 单词查询/搜索
- [x] Riverpod providers (NotifierProvider for Riverpod 3.x)
- [x] FuriganaText 振假名组件
- [x] 词单浏览页 (搜索, 英/日 Tab)
- [x] 词单详情页 (展开例句)
- [x] main.dart 首次启动导入内置词单
- **Status:** complete

### Phase 3: FSRS 与闪卡学习
- [x] FsrsService 封装 (Scheduler, Card, Rating)
- [x] UserProgress 模型
- [x] ProgressRepository
- [x] SessionRepository
- [x] StudySessionNotifier (FSRS 2.0.1 API fix)
- [x] StudySetupScreen (词单选择, 新词/复习上限滑块)
- [x] StudySessionScreen (闪卡翻转动画, 评分, 星标)
- [x] SessionSummaryScreen (统计网格, 打卡/首页按钮)
- [x] Build verification
- **Status:** complete

### Phase 4: TTS 语音合成
- [x] TtsService (英/日切换, 语速调节, 跨平台)
- [x] 闪卡集成 (发音按钮, 翻转自动播放)
- **Status:** complete

### Phase 5: 听力复习模式
- [x] AudioReviewNotifier (manual + auto mode)
- [x] 听力设置页 (词单选择, 模式选择, 词数限制)
- [x] 听力会话页 (自动播放模式, 2级评分)
- **Status:** complete

### Phase 6: AI 短文生成
- [x] AiService 抽象接口
- [x] OpenAI/DeepSeek/Ollama 三种实现
- [x] 手动复制粘贴模式 (无 API Key 时)
- [x] 选词算法 + Prompt 模板
- [x] 短文页 + 测验页
- **Status:** complete

### Phase 7: 打卡与成就系统
- [x] CheckinRepository (打卡记录, 连续计算, 成就检查)
- [x] CheckinNotifier + CheckinScreen
- [x] 成就系统 (10种成就, 解锁逻辑)
- [x] 打卡截图生成 (CheckinCard → screenshot PNG)
- [x] 分享功能 (手机 share_plus / 桌面 保存文件)
- **Status:** complete

### Phase 8: 统计与打磨
- [x] SessionRepository.getDailyStats() + getAllTimeStats()
- [x] CheckinRepository.getCheckinHistory()
- [x] StatisticsScreen (fl_chart 柱状图/折线图/打卡日历)
- [x] 首页仪表盘 (实时数据: 连续打卡, 今日统计, 总词数)
- [x] SettingsRepository + SettingsNotifier (DB持久化)
- [x] SettingsScreen (AI后端, API Key, TTS速度, 学习设置, 主题模式)
- [x] 暗色模式 (themeMode 从 settings 驱动)
- [x] Build verification ✓
- **Status:** complete

### Phase 9: 测试与发布
- [x] 单元/Widget 测试 (40 tests passing)
- [x] Windows Release 构建 (wordmaster.exe)
- [x] Android Release 构建 (app-release.apk, 57.2MB)
- **Status:** complete

## Key Decisions
| Decision | Rationale |
|----------|-----------|
| Flutter (Dart) | 单代码库支持 Android + iOS + Windows + macOS + Linux |
| SQLite (sqflite + sqflite_common_ffi) | 离线优先，跨平台 |
| Riverpod 3.x (NotifierProvider) | 现代状态管理，StateProvider 已移除 |
| GoRouter 17.1.0 | 声明式路由，Flutter 官方维护 |
| FSRS 2.0.1 (fsrs package) | 现代间隔重复算法，Anki 已采用 |
| 统一 Word 表 (英+日) | 复习逻辑统一，无需 UNION 查询 |
| `any` version constraints | Flutter 3.38.9 兼容性 |
| Manual AI mode (copy-paste) | 无 API Key 时仍可使用 AI 短文功能 |
| AsyncValue.value (not valueOrNull) | Riverpod 3.x API change |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| go_router version mismatch | 1 | Used `any` for version constraints |
| nuget.exe not found | 1 | Installed via winget |
| StateProvider not found (Riverpod 3.x) | 1 | Replaced with NotifierProvider |
| FSRS API mismatch (17+ errors) | 1 | Explored pub cache, found correct API |
| fsrs_service.dart wrong API | 1 | Rewrote with Scheduler, Card(cardId:) |
| SDK version ^3.10.8 but Dart 3.10.7 | 1 | Changed to ^3.10.0 |
| AsyncValue.valueOrNull not in Riverpod 3.x | 1 | Changed to .value |

## Notes
- FSRS 2.0.1: Card has cardId, state, step, stability(nullable), difficulty(nullable), due, lastReview
- FSRS 2.0.1: Card does NOT have reps, lapses - track ourselves in user_progress
- FSRS State enum: learning(1), review(2), relearning(3) - use .value not .index
- Riverpod 3.x: No StateProvider, use NotifierProvider; AsyncValue uses .value not .valueOrNull
