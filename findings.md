# Findings & Decisions

## Requirements
- 多平台: Android/iOS + Windows/macOS/Linux
- 英语 (CET-4/6) + 日语 (JLPT N5-N3) 词汇学习
- FSRS 间隔重复算法 (艾宾浩斯)
- TTS 发音 (英/日)
- 听力复习模式 (自动播放)
- AI 短文生成 (可切换 OpenAI/DeepSeek/Ollama)
- 每日打卡 + 截图分享 (含成就和软件宣传)
- 响应式布局 (手机底部导航/桌面侧边栏)

## FSRS 2.0.1 API Findings (CRITICAL)

### Card Class
| Field | Type | Notes |
|-------|------|-------|
| cardId | int | Required, defaults to epoch ms |
| state | State | learning/review/relearning |
| step | int? | null if in Review state |
| stability | double? | nullable |
| difficulty | double? | nullable |
| due | DateTime | next due date |
| lastReview | DateTime? | nullable |

**Card does NOT have:** reps, lapses, elapsedDays, scheduledDays

### ReviewLog Class
| Field | Type |
|-------|------|
| cardId | int |
| rating | Rating |
| reviewDateTime | DateTime |
| reviewDuration | int? |

### State Enum
- `State.learning` = 1
- `State.review` = 2
- `State.relearning` = 3
- Access int: `state.value`
- Create from int: `State.fromValue(int)`

### Rating Enum
- `Rating.again` = 1
- `Rating.hard` = 2
- `Rating.good` = 3
- `Rating.easy` = 4
- Create from int: `Rating.fromValue(int)`

### Key API Methods
- `Scheduler(parameters: defaultParameters, desiredRetention: 0.9, ...)`
- `scheduler.reviewCard(card, rating, reviewDateTime: dt)` → `({Card card, ReviewLog reviewLog})`
- `scheduler.getCardRetrievability(card)` → double
- `Card.toMap()` / `Card.fromMap(map)` for serialization
- `ReviewLog.toMap()` / `ReviewLog.fromMap(map)` for serialization

## Riverpod 3.x Findings
- `StateProvider` removed in Riverpod 3.1.0
- Replace with `NotifierProvider` + custom `Notifier<T>` class
- Example: `WordSearchQueryNotifier extends Notifier<String>` with `setQuery()` method
- UI uses `ref.read(provider.notifier).setQuery(value)` instead of `.state = value`

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Unified Word table | EN and JA in same table, language-specific fields nullable |
| JSON asset loading → SQLite | First launch imports bundled word lists |
| Feature-first architecture | Each feature has domain/data/application/presentation layers |
| _DefaultDateTime hack | Allows const StudySessionState constructor |
| 1:5 interleaving | Every 5 review words, insert 1 new word |
| Re-add "Again" cards | Rating 1 cards go to end of queue |

## Key File Paths
- Database: `lib/src/core/database/database_helper.dart`
- Router: `lib/src/core/routing/app_router.dart`
- Theme: `lib/src/core/theme/app_colors.dart`
- Word models: `lib/src/features/word_lists/domain/models/word.dart`
- FSRS service: `lib/src/features/study/domain/services/fsrs_service.dart`
- Progress repo: `lib/src/features/study/data/repositories/progress_repository.dart`
- Session notifier: `lib/src/features/study/application/study_session_notifier.dart`
- Study screens: `lib/src/features/study/presentation/screens/`

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Flutter 3.38.9 strict version constraints | Used `any` for all pub dependencies |
| NuGet missing for flutter_tts Windows | winget install Microsoft.NuGet + add source |
| FSRS package API completely different from docs | Explored pub cache source, found actual class names/methods |
| Riverpod 3.x StateProvider removal | Created Notifier<T> subclass pattern |
