# WordMaster - Smart Vocabulary Learning App

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux-blue)

**An intelligent vocabulary learning app with spaced repetition, powered by FSRS algorithm.**

[English](#english) | [中文](#中文) | [日本語](#日本語)

</div>

---

## English

### Features

- **Smart Spaced Repetition**: Uses the FSRS (Free Spaced Repetition Scheduler) algorithm for optimal memory retention
- **AI-Generated Reading Passages**: LLM creates contextual short articles using your vocabulary words, reinforcing memory through meaningful context
- **40,000+ Vocabulary Words**: Comprehensive word lists including CEFR (A1-C2), JLPT (N5-N1), CET-4/6, TOEFL, and more
- **4,200+ Kanji Characters**: JLPT kanji (N5-N1) and Japanese school curriculum (Grades 1-6, Middle, High School)
- **Multi-language Support**: Learn English and Japanese vocabulary
- **Offline TTS**: Text-to-speech using sherpa-onnx (no internet required)
- **Audio Review Mode**: Listen-based vocabulary practice
- **Daily Check-in System**: Track your learning streaks and achievements
- **Statistics Dashboard**: Visualize your learning progress with charts
- **Cross-platform**: Works on Windows, Android, iOS, macOS, and Linux
- **Flexible AI Backend**: Supports OpenAI, DeepSeek, Ollama (local), or manual mode

### Available Word Lists

| Category | Lists | Total |
|----------|-------|-------|
| **CEFR English** | A1, A2, B1, B2, C1, C2 | 9,441 words |
| **Chinese Exams** | 中考, 高考, CET-4, CET-6, 考研 | 20,000+ words |
| **Standardized Tests** | TOEFL, SAT | 14,000+ words |
| **JLPT Japanese** | N5, N4, N3, N2, N1 | 20,000+ words |
| **JLPT Kanji** | N5, N4, N3, N2, N1 | 2,135 kanji |
| **School Kanji** | 小学1-6年, 中学校, 高等学校 | 2,136 kanji |

Word lists include Chinese translations, IPA phonetics, and example sentences. Kanji lists include onyomi/kunyomi readings and example words. See [wordmaster-wordlists](https://github.com/lratusa/wordmaster-wordlists) for details.

### Installation

#### Prerequisites
- Flutter SDK 3.38.0 or higher
- Dart SDK 3.10.0 or higher

#### Build from Source

```bash
# Clone the repository
git clone https://github.com/lratusa/wordmaster.git
cd wordmaster

# Install dependencies
flutter pub get

# Run the app
flutter run

# Build for release
flutter build windows    # Windows
flutter build apk        # Android
flutter build ios        # iOS
flutter build macos      # macOS
flutter build linux      # Linux
```

#### Download TTS Models (Optional)

For offline text-to-speech functionality, download voice packs directly in the app:

1. Open the app
2. Go to **Settings** > **TTS Voice Models**
3. Click the download button for your preferred language:
   - English (US) - ~75 MB
   - English (UK) - ~65 MB
   - Japanese - ~55 MB
   - Chinese + English - ~150 MB

No Python or command line required!

### Architecture

```
lib/
├── src/
│   ├── core/               # Core utilities and services
│   │   ├── database/       # SQLite database helper
│   │   ├── services/       # TTS, settings services
│   │   └── theme/          # App theming
│   └── features/           # Feature modules
│       ├── study/          # Flashcard study system
│       ├── audio_review/   # Audio-based review
│       ├── word_lists/     # Word list management
│       ├── checkin/        # Daily check-in
│       ├── statistics/     # Learning analytics
│       └── settings/       # App settings
```

### Tech Stack

- **State Management**: Riverpod 3.x
- **Navigation**: GoRouter
- **Database**: SQLite (sqflite_common_ffi)
- **Spaced Repetition**: FSRS 2.0.1
- **TTS**: sherpa-onnx (offline neural TTS)
- **Charts**: fl_chart

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 中文

### 功能特点

- **智能间隔重复**: 采用 FSRS（自由间隔重复调度器）算法，优化记忆效果
- **AI 生成阅读短文**: 大语言模型根据你的生词自动生成情境短文，在上下文中加深记忆
- **40,000+ 词汇量**: 包含 CEFR (A1-C2)、JLPT (N5-N1)、四六级、托福等完整词库
- **4,200+ 汉字**: JLPT 汉字 (N5-N1) 及日本学校课程汉字 (小学1-6年、中学、高中)
- **多语言支持**: 学习英语和日语词汇
- **离线语音**: 使用 sherpa-onnx 实现文字转语音（无需联网）
- **听力训练模式**: 基于听力的词汇练习
- **每日打卡系统**: 追踪学习连续天数和成就
- **统计仪表盘**: 通过图表可视化学习进度
- **跨平台**: 支持 Windows、Android、iOS、macOS 和 Linux
- **灵活的 AI 后端**: 支持 OpenAI、DeepSeek、Ollama（本地）或手动模式

### 词库列表

| 类型 | 词库 | 词汇量 |
|------|------|--------|
| **CEFR 欧标** | A1, A2, B1, B2, C1, C2 | 9,441 |
| **国内考试** | 中考, 高考, 四级, 六级, 考研 | 20,000+ |
| **留学考试** | 托福, SAT | 14,000+ |
| **日语 JLPT** | N5, N4, N3, N2, N1 | 20,000+ |

所有词汇包含中文释义、IPA音标和例句。详见 [wordmaster-wordlists](https://github.com/lratusa/wordmaster-wordlists)。

### 安装说明

#### 环境要求
- Flutter SDK 3.38.0 或更高版本
- Dart SDK 3.10.0 或更高版本

#### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/lratusa/wordmaster.git
cd wordmaster

# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建发布版本
flutter build windows    # Windows
flutter build apk        # Android
flutter build ios        # iOS
flutter build macos      # macOS
flutter build linux      # Linux
```

#### 下载语音模型（可选）

如需离线语音功能，直接在应用内下载语音包：

1. 打开应用
2. 进入 **设置** > **TTS 语音模型**
3. 点击下载按钮选择语言：
   - 英语（美式）- 约 75 MB
   - 英语（英式）- 约 65 MB
   - 日语 - 约 55 MB
   - 中英双语 - 约 150 MB

无需 Python，一键下载！

### 技术栈

- **状态管理**: Riverpod 3.x
- **路由导航**: GoRouter
- **数据库**: SQLite (sqflite_common_ffi)
- **间隔重复**: FSRS 2.0.1
- **语音合成**: sherpa-onnx（离线神经网络语音）
- **图表**: fl_chart

### 贡献指南

欢迎贡献代码！请随时提交 Pull Request。

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m '添加某个很棒的功能'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

## 日本語

### 機能

- **スマート間隔反復**: FSRS（自由間隔反復スケジューラ）アルゴリズムによる最適な記憶定着
- **AI生成リーディング**: LLMが学習中の単語を使って短い文章を自動生成、文脈の中で記憶を強化
- **40,000+語彙**: CEFR (A1-C2)、JLPT (N5-N1)、TOEFL等の完全な語彙リスト
- **4,200+漢字**: JLPT漢字 (N5-N1) および日本の学校カリキュラム漢字 (小学1-6年、中学、高校)
- **多言語対応**: 英語と日本語の語彙学習
- **オフラインTTS**: sherpa-onnxを使用した音声読み上げ（インターネット不要）
- **リスニング練習モード**: 聴覚ベースの語彙練習
- **毎日チェックインシステム**: 学習連続日数と実績の追跡
- **統計ダッシュボード**: グラフで学習進捗を可視化
- **クロスプラットフォーム**: Windows、Android、iOS、macOS、Linuxに対応
- **柔軟なAIバックエンド**: OpenAI、DeepSeek、Ollama（ローカル）、または手動モードに対応

### 語彙リスト

| カテゴリ | リスト | 語彙数 |
|----------|--------|--------|
| **CEFR 英語** | A1, A2, B1, B2, C1, C2 | 9,441 |
| **中国試験** | 中考, 高考, CET-4, CET-6, 考研 | 20,000+ |
| **標準テスト** | TOEFL, SAT | 14,000+ |
| **JLPT 日本語** | N5, N4, N3, N2, N1 | 20,000+ |

全ての語彙に中国語訳、IPA発音記号、例文が含まれています。詳細は [wordmaster-wordlists](https://github.com/lratusa/wordmaster-wordlists) をご覧ください。

### インストール

#### 必要条件
- Flutter SDK 3.38.0以上
- Dart SDK 3.10.0以上

#### ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/lratusa/wordmaster.git
cd wordmaster

# 依存関係をインストール
flutter pub get

# アプリを実行
flutter run

# リリースビルド
flutter build windows    # Windows
flutter build apk        # Android
flutter build ios        # iOS
flutter build macos      # macOS
flutter build linux      # Linux
```

#### 音声モデルのダウンロード（オプション）

オフライン音声機能を使用する場合、アプリ内で直接ダウンロードできます：

1. アプリを開く
2. **設定** > **TTS 音声モデル** に移動
3. お好みの言語のダウンロードボタンをクリック：
   - 英語（アメリカ）- 約 75 MB
   - 英語（イギリス）- 約 65 MB
   - 日本語 - 約 55 MB
   - 中国語 + 英語 - 約 150 MB

Pythonは不要、ワンクリックでダウンロード！

### 技術スタック

- **状態管理**: Riverpod 3.x
- **ナビゲーション**: GoRouter
- **データベース**: SQLite (sqflite_common_ffi)
- **間隔反復**: FSRS 2.0.1
- **音声合成**: sherpa-onnx（オフラインニューラルTTS）
- **グラフ**: fl_chart

### コントリビューション

コントリビューションを歓迎します！お気軽にPull Requestを提出してください。

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m '素晴らしい機能を追加'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. Pull Requestを作成

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FSRS](https://github.com/open-spaced-repetition/fsrs4anki) - Free Spaced Repetition Scheduler
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) - Offline speech recognition and synthesis
- [Flutter](https://flutter.dev) - UI toolkit for building natively compiled applications

---

<div align="center">
Made with ❤️ by the WordMaster Team
</div>
