import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../common_widgets/furigana_text.dart';
import '../../../word_lists/application/word_list_providers.dart';
import '../../../word_lists/data/repositories/word_repository.dart';
import '../../../word_lists/domain/enums/language.dart';
import '../../../word_lists/domain/models/word.dart';
import '../../application/study_session_notifier.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<Word> _options = [];
  int? _selectedIndex;
  bool _answered = false;
  int _correctIndex = 0;
  Timer? _advanceTimer;
  int? _currentWordId; // Track which word options were loaded for

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
        body: Center(child: Text('没有可学习的单词')),
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
              final result =
                  await tts.speak(item.word.word, language: item.word.language.code);
              if (result == TtsSpeakResult.languageNotSupported && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(tts.getUnsupportedLanguageMessage(item.word.language.code)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              item.progress.isStarred ? Icons.star : Icons.star_border,
              color: item.progress.isStarred ? AppColors.checkinGold : null,
            ),
            onPressed: () => ref.read(studySessionProvider.notifier).toggleStar(),
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

          // Word display area
          Expanded(
            flex: 2,
            child: _buildWordDisplay(item),
          ),

          // Options area
          Expanded(
            flex: 3,
            child: _buildOptions(item.word),
          ),
        ],
      ),
    );
  }

  Widget _buildWordDisplay(StudyItem item) {
    final word = item.word;
    final isJapanese = word.language == Language.ja;
    final theme = Theme.of(context);

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
          if (isJapanese)
            FuriganaText(
              text: word.word,
              reading: word.reading,
              textStyle: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              word.word,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          if (!isJapanese && word.phonetic != null)
            Text(
              word.phonetic!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          if (word.partOfSpeech != null) ...[
            const SizedBox(height: 8),
            Text(
              word.partOfSpeech!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptions(Word correctWord) {
    if (_options.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _options.length; i++) ...[
            _buildOptionButton(i, _options[i]),
            if (i < _options.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, Word option) {
    final isSelected = _selectedIndex == index;
    final isCorrect = index == _correctIndex;

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData? icon;

    if (!_answered) {
      // Not yet answered
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = AppColors.textSecondary.withValues(alpha: 0.3);
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    } else if (isSelected && isCorrect) {
      // Selected and correct
      backgroundColor = AppColors.success.withValues(alpha: 0.15);
      borderColor = AppColors.success;
      textColor = AppColors.success;
      icon = Icons.check_circle;
    } else if (isSelected && !isCorrect) {
      // Selected but wrong
      backgroundColor = AppColors.error.withValues(alpha: 0.15);
      borderColor = AppColors.error;
      textColor = AppColors.error;
      icon = Icons.cancel;
    } else if (isCorrect) {
      // Not selected but is correct (show correct answer)
      backgroundColor = AppColors.success.withValues(alpha: 0.1);
      borderColor = AppColors.success;
      textColor = AppColors.success;
    } else {
      // Other options after answering
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
                option.translationCn,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
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

  /// Check if text contains Chinese characters
  bool _containsChinese(String text) {
    // Chinese character ranges: CJK Unified Ideographs
    return text.runes.any((rune) =>
        (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK Unified Ideographs
        (rune >= 0x3400 && rune <= 0x4DBF) || // CJK Extension A
        (rune >= 0xF900 && rune <= 0xFAFF));  // CJK Compatibility Ideographs
  }

  Future<void> _loadOptions(Word correctWord) async {
    // Prevent duplicate loads
    if (_currentWordId == correctWord.id) return;

    final wordRepo = WordRepository();
    final distractors = await wordRepo.getDistractors(
      wordListId: correctWord.wordListId,
      excludeWordId: correctWord.id!,
      language: correctWord.language.code,
      preferPartOfSpeech: correctWord.partOfSpeech,
      count: 5, // Request more to filter
    );

    // Filter out distractors with non-Chinese translations
    final validDistractors = distractors
        .where((d) => _containsChinese(d.translationCn))
        .take(3)
        .toList();

    // Combine correct word with distractors
    final allOptions = [correctWord, ...validDistractors];
    allOptions.shuffle();

    if (mounted) {
      setState(() {
        _currentWordId = correctWord.id;
        _options = allOptions;
        _correctIndex = allOptions.indexWhere((w) => w.id == correctWord.id);
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

    // Play TTS for correct word
    final session = ref.read(studySessionProvider);
    final item = session.currentItem;
    if (item != null) {
      final tts = ref.read(ttsServiceProvider);
      tts.speak(item.word.word, language: item.word.language.code);
    }

    // Rate the card based on answer
    // Correct: rating 4 (Easy) - no re-queue
    // Wrong: rating 1 (Again) - re-queue
    final rating = isCorrect ? 4 : 1;

    // Delay before advancing to next word
    final delay = isCorrect ? 800 : 1500;
    _advanceTimer = Timer(Duration(milliseconds: delay), () {
      ref.read(studySessionProvider.notifier).rateCard(rating);
      if (mounted) {
        setState(() {
          _currentWordId = null; // Reset to trigger loading new options
          _options = [];
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
