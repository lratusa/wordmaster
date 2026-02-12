# WordMaster 背单词 App - Task Plan

## Goal
构建一个多平台背单词应用（英语+日语），支持 FSRS 艾宾浩斯复习、TTS发音、听力训练、AI短文生成（可切换 OpenAI/DeepSeek/Ollama + 手动复制粘贴模式）、每日打卡截图分享。

## Current Phase
**Phase 9 COMPLETE** - All phases finished. Project ready for distribution.

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
