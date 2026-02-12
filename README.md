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
- **Multi-language Support**: Learn English and Japanese vocabulary
- **Offline TTS**: Text-to-speech using sherpa-onnx (no internet required)
- **Audio Review Mode**: Listen-based vocabulary practice
- **Daily Check-in System**: Track your learning streaks and achievements
- **Statistics Dashboard**: Visualize your learning progress with charts
- **Cross-platform**: Works on Windows, Android, iOS, macOS, and Linux

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

For offline text-to-speech functionality:

```bash
cd tts_server
python download_models.py en-us    # English (US)
python download_models.py ja       # Japanese
python download_models.py zh       # Chinese
```

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
- **多语言支持**: 学习英语和日语词汇
- **离线语音**: 使用 sherpa-onnx 实现文字转语音（无需联网）
- **听力训练模式**: 基于听力的词汇练习
- **每日打卡系统**: 追踪学习连续天数和成就
- **统计仪表盘**: 通过图表可视化学习进度
- **跨平台**: 支持 Windows、Android、iOS、macOS 和 Linux

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

如需离线语音功能：

```bash
cd tts_server
python download_models.py en-us    # 英语（美式）
python download_models.py ja       # 日语
python download_models.py zh       # 中文
```

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
- **多言語対応**: 英語と日本語の語彙学習
- **オフラインTTS**: sherpa-onnxを使用した音声読み上げ（インターネット不要）
- **リスニング練習モード**: 聴覚ベースの語彙練習
- **毎日チェックインシステム**: 学習連続日数と実績の追跡
- **統計ダッシュボード**: グラフで学習進捗を可視化
- **クロスプラットフォーム**: Windows、Android、iOS、macOS、Linuxに対応

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

オフライン音声機能を使用する場合：

```bash
cd tts_server
python download_models.py en-us    # 英語（アメリカ）
python download_models.py ja       # 日本語
python download_models.py zh       # 中国語
```

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
