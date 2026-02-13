import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../word_lists/application/word_list_providers.dart';
import '../../../word_lists/data/repositories/word_repository.dart';
import '../../../word_lists/domain/models/word.dart';
import '../../application/study_session_notifier.dart';

/// Kanji Selection Quiz Screen (汉字选择)
/// Shows example word with reading hint, user selects correct kanji
/// Falls back to reading test when no examples available
class KanjiSelectionQuizScreen extends ConsumerStatefulWidget {
  const KanjiSelectionQuizScreen({super.key});

  @override
  ConsumerState<KanjiSelectionQuizScreen> createState() =>
      _KanjiSelectionQuizScreenState();
}

class _KanjiSelectionQuizScreenState
    extends ConsumerState<KanjiSelectionQuizScreen> {
  List<Word> _kanjiOptions = [];
  List<String> _readingOptions = []; // For fallback mode
  int? _selectedIndex;
  bool _answered = false;
  int _correctIndex = 0;
  Timer? _advanceTimer;
  int? _currentWordId;

  // Current example being shown
  String _exampleWord = '';
  String _exampleReading = '';
  String _exampleTranslation = '';
  bool _isFallbackMode = false; // True when no examples, use reading test

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(studySessionProvider);

    if (session.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/study/summary');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final item = session.currentItem;
    if (item == null) {
      return const Scaffold(
        body: Center(child: Text('没有可学习的汉字')),
      );
    }

    // Load options only when word changes
    if (_currentWordId != item.word.id) {
      _loadOptions(item.word);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${session.currentIndex + 1} / ${session.totalWords}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () async {
              final tts = ref.read(ttsServiceProvider);
              // Speak the example word or the kanji itself
              if (_exampleWord.isNotEmpty) {
                await tts.speak(_exampleWord, language: 'ja');
              } else {
                await tts.speak(item.word.word, language: 'ja');
              }
            },
          ),
          IconButton(
            icon: Icon(
              item.progress.isStarred ? Icons.star : Icons.star_border,
              color: item.progress.isStarred ? AppColors.checkinGold : null,
            ),
            onPressed: () =>
                ref.read(studySessionProvider.notifier).toggleStar(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: session.totalWords > 0
                ? session.currentIndex / session.totalWords
                : 0,
            minHeight: 3,
          ),

          // Question display area
          Expanded(
            flex: 2,
            child: _isFallbackMode
                ? _buildFallbackDisplay(item)
                : _buildExampleDisplay(item),
          ),

          // Options area
          Expanded(
            flex: 3,
            child: _isFallbackMode ? _buildReadingOptions() : _buildKanjiOptions(),
          ),
        ],
      ),
    );
  }

  /// Display for kanji selection mode (with example)
  Widget _buildExampleDisplay(StudyItem item) {
    final word = item.word;
    final theme = Theme.of(context);

    // Create display with blank for the kanji
    // Example: "大雨" with kanji "雨" -> "大＿＿"
    String displayWord = _exampleWord;
    if (_exampleWord.isNotEmpty && !_answered) {
      // Replace the kanji with underscore placeholder
      displayWord = _exampleWord.replaceAll(word.word, '＿＿');
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.isNewWord)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '新词',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          // Example word with blank
          Text(
            displayWord,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 36,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Reading hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _exampleReading,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chinese translation
          Text(
            _exampleTranslation,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          // Show correct answer after answering
          if (_answered) ...[
            const SizedBox(height: 16),
            Text(
              '正确答案: ${word.word} (${word.translationCn})',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Fallback display - same as reading test
  Widget _buildFallbackDisplay(StudyItem item) {
    final word = item.word;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Indicator that this is fallback mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '读音测试',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          if (item.isNewWord)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '新词',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          // Large kanji display
          Text(
            word.word,
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 72,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Chinese meaning
          Text(
            '(${word.translationCn})',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanjiOptions() {
    if (_kanjiOptions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _kanjiOptions.length; i++) ...[
            _buildKanjiOptionButton(i, _kanjiOptions[i]),
            if (i < _kanjiOptions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingOptions() {
    if (_readingOptions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _readingOptions.length; i++) ...[
            _buildReadingOptionButton(i, _readingOptions[i]),
            if (i < _readingOptions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildKanjiOptionButton(int index, Word kanji) {
    final isSelected = _selectedIndex == index;
    final isCorrect = index == _correctIndex;

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData? icon;

    if (!_answered) {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.3);
      textColor =
          Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    } else if (isSelected && isCorrect) {
      backgroundColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success;
      textColor = AppColors.success;
      icon = Icons.check_circle;
    } else if (isSelected && !isCorrect) {
      backgroundColor = AppColors.error.withValues(alpha: 0.15);
      borderColor = AppColors.error;
      textColor = AppColors.error;
      icon = Icons.cancel;
    } else if (isCorrect) {
      backgroundColor = AppColors.success.withValues(alpha: 0.1);
      borderColor = AppColors.success;
      textColor = AppColors.success;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.2);
      textColor = AppColors.textSecondary;
    }

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton(
        onPressed: _answered ? null : () => _selectAnswer(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                kanji.word,
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, color: textColor, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingOptionButton(int index, String reading) {
    final isSelected = _selectedIndex == index;
    final isCorrect = index == _correctIndex;

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData? icon;

    if (!_answered) {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.3);
      textColor =
          Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    } else if (isSelected && isCorrect) {
      backgroundColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success;
      textColor = AppColors.success;
      icon = Icons.check_circle;
    } else if (isSelected && !isCorrect) {
      backgroundColor = AppColors.error.withValues(alpha: 0.15);
      borderColor = AppColors.error;
      textColor = AppColors.error;
      icon = Icons.cancel;
    } else if (isCorrect) {
      backgroundColor = AppColors.success.withValues(alpha: 0.1);
      borderColor = AppColors.success;
      textColor = AppColors.success;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.2);
      textColor = AppColors.textSecondary;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _answered ? null : () => _selectAnswer(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reading,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, color: textColor, size: 24),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOptions(Word correctWord) async {
    if (_currentWordId == correctWord.id) return;

    final wordRepo = WordRepository();

    // Check if kanji has examples
    final hasExamples = correctWord.hasExamples;

    if (hasExamples) {
      // Normal mode: kanji selection with example
      final example = correctWord.exampleSentences.first;

      // Get kanji distractors
      final distractors = await wordRepo.getKanjiDistractors(
        wordListId: correctWord.wordListId,
        excludeWordId: correctWord.id!,
        count: 3,
      );

      // Only use kanji selection mode if we have at least 1 distractor
      if (distractors.isNotEmpty) {
        // Combine and shuffle
        final options = [correctWord, ...distractors];
        options.shuffle();

        if (mounted) {
          setState(() {
            _currentWordId = correctWord.id;
            _isFallbackMode = false;
            _kanjiOptions = options;
            _readingOptions = [];
            _exampleWord = example.sentence; // "大雨" etc
            // Use example's reading if available, otherwise fall back to word's reading
            _exampleReading = example.reading ??
                correctWord.reading ??
                correctWord.allReadings.firstOrNull ??
                '';
            _exampleTranslation = example.translationCn;
            _correctIndex = options.indexWhere((w) => w.id == correctWord.id);
            _selectedIndex = null;
            _answered = false;
          });
        }
        return;
      }
      // Fall through to reading test mode if no kanji distractors
    }

    // Fallback mode: reading test (no examples available OR no kanji distractors)
    final allReadings = correctWord.allReadings;
    if (allReadings.isEmpty) {
      // No readings available - auto advance with correct answer
      if (mounted) {
        setState(() {
          _currentWordId = correctWord.id;
          _isFallbackMode = true;
          _readingOptions = [correctWord.word]; // Just show the kanji itself
          _correctIndex = 0;
        });
        // Auto-advance after showing the word briefly
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(studySessionProvider.notifier).rateCard(4); // Auto-pass
            setState(() {
              _currentWordId = null;
              _kanjiOptions = [];
              _readingOptions = [];
            });
          }
        });
      }
      return;
    }

    final correctReading = (List<String>.from(allReadings)..shuffle()).first;

    final distractors = await wordRepo.getReadingDistractors(
      correctReading: correctReading,
      wordListId: correctWord.wordListId,
      excludeWordId: correctWord.id!,
      count: 3,
    );

    final options = [correctReading, ...distractors];
    options.shuffle();

    if (mounted) {
      setState(() {
        _currentWordId = correctWord.id;
        _isFallbackMode = true;
        _kanjiOptions = [];
        _readingOptions = options;
        _exampleWord = '';
        _exampleReading = correctReading;
        _exampleTranslation = '';
        _correctIndex = options.indexOf(correctReading);
        _selectedIndex = null;
        _answered = false;
      });
    }
  }

  void _selectAnswer(int index) {
    if (_answered) return;

    final isCorrect = index == _correctIndex;

    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    // Speak the correct answer
    final tts = ref.read(ttsServiceProvider);
    if (_isFallbackMode) {
      if (_exampleReading.isNotEmpty) {
        tts.speak(_exampleReading, language: 'ja');
      }
    } else {
      if (_exampleWord.isNotEmpty) {
        tts.speak(_exampleWord, language: 'ja');
      }
    }

    // Rate the card
    final rating = isCorrect ? 4 : 1;

    // Delay before advancing
    final delay = isCorrect ? 800 : 1500;
    _advanceTimer = Timer(Duration(milliseconds: delay), () {
      ref.read(studySessionProvider.notifier).rateCard(rating);
      if (mounted) {
        setState(() {
          _currentWordId = null;
          _kanjiOptions = [];
          _readingOptions = [];
          _selectedIndex = null;
          _answered = false;
        });
      }
    });
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出学习？'),
        content: const Text('当前进度会保存，你可以稍后继续。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续学习'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.invalidate(allWordListsProvider);
              context.go('/');
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
