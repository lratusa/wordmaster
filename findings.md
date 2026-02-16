# Findings & Decisions

## French Language Support Findings (Phase 15)

### TTS Model Availability
sherpa-onnx provides VITS/Piper models for French:
- **vits-piper-fr_FR-siwis-medium** (~65 MB) - Female voice, standard French
- **vits-piper-fr_FR-upmc-medium** (~55 MB) - Alternative voice
- Model repository: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models

### Current Language Architecture
- **Language enum**: `lib/src/features/word_lists/domain/enums/language.dart`
  - Currently: `Language.en`, `Language.ja`
  - Need to add: `Language.fr('fr', 'Français', '法语')`
- **TTS Service**: Hybrid system
  - sherpa-onnx for English/Chinese (offline neural TTS)
  - flutter_tts for Japanese (system TTS fallback)
  - French will use sherpa-onnx (VITS models)

### French Special Characters (UTF-8 Critical)
French uses diacritical marks that MUST be tested:
- **Accents**: é, è, ê, ë (like "être", "élève", "français")
- **Cedilla**: ç (like "garçon", "français")
- **Ligature**: œ (like "cœur", "œuf")
- **Grave accent**: ù (like "où")

**Testing Requirements:**
1. JSON word list must be UTF-8 encoded
2. SQLite database stores UTF-8 correctly (default for SQLite3)
3. **CRITICAL**: sherpa-onnx TTS input must handle UTF-8
   - Test words: "être", "français", "cœur", "élève", "garçon"
   - Verify pronunciation quality with special characters

### Word List Sources & Sizes
**CEFR Levels** (using FLE - Français Langue Étrangère official lists):
- A1 (Beginner) - ~500 words
- A2 (Elementary) - ~1000 words
- B1 (Intermediate) - ~1500 words
- B2 (Upper Intermediate) - ~2000 words
- C1 (Advanced) - ~2500 words
- C2 (Proficient) - ~3000 words

**Sources:**
- CEFR lists: Available from FLE official resources
- DELF/DALF: May need manual curation (no official public word lists)
- Thematic lists: Can be derived from CEFR A1-B1 words

### Test Coverage Requirements (Phase 15)
Building on Phase 13's 231 tests, add:
1. **Unit Tests:**
   - `Language.fr` enum parsing/serialization
   - French TTS model configuration
2. **Repository Tests:**
   - French wordlist download (mock HTTP)
   - French wordlist parsing with special characters
   - UTF-8 handling in Word model
3. **Widget Tests:**
   - French tab in word list browser
   - French word display with special characters

### Implementation Checklist
| Component | File | Change Required |
|-----------|------|-----------------|
| Language enum | `word_lists/domain/enums/language.dart` | Add `fr` |
| TTS models | `core/services/tts_model_downloader.dart` | Add French VITS models |
| TTS service | `core/services/tts_service.dart` | Add 'fr' to `_sherpaLanguages` |
| Wordlist directory | `assets/wordlists/` | Create `french/` folder |
| Wordlist categories | `core/services/wordlist_downloader.dart` | Add French categories |
| Browser UI | `word_lists/presentation/screens/word_list_browser_screen.dart` | Add French tab |

## China Mirror Findings (Phase 12)

### Problem
The app relies on GitHub for word list and TTS model downloads. GitHub is blocked in mainland China (raw.githubusercontent.com and github.com). OpenAI API is also blocked.

### Services blocked in China
| Service | URL | Used for |
|---------|-----|----------|
| GitHub Raw | raw.githubusercontent.com | 37 word list JSON downloads |
| GitHub Releases | github.com/k2-fsa/sherpa-onnx/releases | TTS model tar.bz2 downloads |
| OpenAI | api.openai.com | AI passage generation |

### Services accessible in China
| Service | URL | Used for |
|---------|-----|----------|
| DeepSeek | api.deepseek.com | AI passage generation (Chinese company) |
| Ollama | localhost | AI passage generation (local) |
| Manual mode | N/A | AI passage generation (copy-paste) |

### Mirror Strategy: Self-hosted Cloud Server
- **Gitee rejected** — repos flagged for "外链滥用 (RAW)" when used for file hosting
- **Solution**: Alibaba Cloud server at `47.93.144.50` running nginx in Docker
- Nginx serves `/wordmaster/` path from `/var/www/wordmaster/` volume mount

### URL Mapping
| Resource | International (GitHub) | China (Cloud Server) |
|----------|----------------------|----------------------|
| Wordlist base | `https://raw.githubusercontent.com/lratusa/wordmaster-wordlists/main` | `http://47.93.144.50/wordmaster/wordlists` |
| TTS model base | `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models` | `http://47.93.144.50/wordmaster/tts-models` |

### Server Setup
- Docker container `fish-guide` with nginx 1.21.5
- Volume mount: `/var/www/wordmaster` → `/usr/share/nginx/html/wordmaster` (read-only)
- Config mount: `/var/www/wordmaster/default.conf` → `/etc/nginx/conf.d/default.conf`
- CORS headers enabled for app downloads
- Gzip enabled for JSON

### Server File Sync (Manual Steps)
1. Upload wordlists: `scp -r assets/wordlists/{english,japanese} root@47.93.144.50:/var/www/wordmaster/wordlists/`
2. TTS models downloaded server-to-server from GitHub releases
3. SSH key auth configured for passwordless access

### Current hardcoded URLs in codebase
| File | Line | URL constant |
|------|------|-------------|
| `wordlist_downloader.dart` | 54 | `_githubRaw = 'https://raw.githubusercontent.com'` |
| `tts_model_downloader.dart` | 52-53 | `_baseUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models'` |
| `tts_service.dart` | 616 | `_modelsBaseUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models'` |

### Refactoring approach
- `WordListPackage.url` currently stores full URL including base — will change to store only the relative path (e.g., `english/cefr_a1.json`)
- `TtsModel.url` currently stores full URL — will change to store only the filename (e.g., `vits-piper-en_US-lessac-medium.tar.bz2`)
- New `DownloadMirror` class resolves full URL = baseUrl(region, resourceType) + relativePath
- Region persisted as setting: `download_region` = `'international'` | `'china'`

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
| TTS ignores active_model.txt | Renamed `_detectKokoroModel()` to `_detectActiveModel()`, read active file first |
| TTS shows downloaded models as "not downloaded" | Changed `isModelDownloaded()` to check for any `.onnx` file |
| Wordlist download 404 errors | Fixed URLs: used underscores to match actual repo filenames |
| MeloTTS (zh model) treats English words as OOV | Removed zh model, users should use VITS English models |

## TTS Model Findings
| Model Type | File Pattern | Detection |
|------------|--------------|-----------|
| Kokoro | `model.onnx` + `voices.bin` | Check for voices.bin |
| VITS/Piper | `en_GB-alba-medium.onnx` (varied names) | Check for any `.onnx` file |

## Wordlist Repository Findings
- GitHub repo: `lratusa/wordmaster-wordlists`
- English files: Use mix of hyphens and underscores (inconsistent)
- Japanese files: All use underscores
- Missing: GRE, IELTS, GMAT (no source data available)

## Kanji Quiz Mode Findings

### Kanji JSON Structure
```json
{
  "word": "雨",
  "translation_cn": "雨",
  "onyomi": "ウ",
  "kunyomi": "あめ",
  "examples": [
    {"word": "大雨", "reading": "おおあめ", "translation_cn": "大雨"}
  ]
}
```

### Quiz Mode Detection
- `WordList.isKanjiList` checks if name contains "漢字", "汉字", or "Kanji"
- `Word.isKanji` checks if onyomi or kunyomi is not null

### Distractor Quality
- Reading distractors sorted by length similarity to correct answer
- Chinese character filter prevents English text in options:
  ```dart
  bool _containsChinese(String text) {
    return text.runes.any((rune) =>
        (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK Unified
        (rune >= 0x3400 && rune <= 0x4DBF) || // CJK Extension A
        (rune >= 0xF900 && rune <= 0xFAFF));  // CJK Compatibility
  }
  ```

### Fallback Logic
- Kanji selection mode → Reading test (if no examples)
- Reading test → Use other readings from same kanji (if no distractors)
- No readings at all → Auto-advance with pass
