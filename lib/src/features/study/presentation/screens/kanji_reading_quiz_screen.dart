import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../word_lists/application/word_list_providers.dart';
import '../../../word_lists/data/repositories/word_repository.dart';
import '../../../word_lists/domain/models/word.dart';
import '../../application/study_session_notifier.dart';

/// Kanji Reading Quiz Screen (读音测试)
/// Shows kanji, user selects correct reading from options
class KanjiReadingQuizScreen extends ConsumerStatefulWidget {
  const KanjiReadingQuizScreen({super.key});

  @override
  ConsumerState<KanjiReadingQuizScreen> createState() =>
      _KanjiReadingQuizScreenState();
}

class _KanjiReadingQuizScreenState
    extends ConsumerState<KanjiReadingQuizScreen> {
  List<String> _options = [];
  int? _selectedIndex;
  bool _answered = false;
  int _correctIndex = 0;
  String _correctReading = '';
  Timer? _advanceTimer;
  int? _currentWordId;

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
              // Speak the correct reading
              if (_correctReading.isNotEmpty) {
                await tts.speak(_correctReading, language: 'ja');
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

          // Kanji display area
          Expanded(
            flex: 2,
            child: _buildKanjiDisplay(item),
          ),

          // Options area
          Expanded(
            flex: 3,
            child: _buildOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildKanjiDisplay(StudyItem item) {
    final word = item.word;
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
          // Show onyomi/kunyomi labels after answering
          if (_answered) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.onyomi != null && word.onyomi!.isNotEmpty)
                  _buildReadingChip('音読み', word.onyomi!, AppColors.primary),
                if (word.onyomi != null &&
                    word.onyomi!.isNotEmpty &&
                    word.kunyomi != null &&
                    word.kunyomi!.isNotEmpty)
                  const SizedBox(width: 12),
                if (word.kunyomi != null && word.kunyomi!.isNotEmpty)
                  _buildReadingChip('訓読み', word.kunyomi!, AppColors.success),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingChip(String label, String reading, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            reading,
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
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

  Widget _buildOptionButton(int index, String reading) {
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

    // Get all readings for this kanji
    final allReadings = correctWord.allReadings;
    if (allReadings.isEmpty) {
      // No readings available - auto advance
      if (mounted) {
        setState(() {
          _currentWordId = correctWord.id;
          _options = [correctWord.word]; // Just show the kanji
          _correctReading = correctWord.word;
          _correctIndex = 0;
        });
        // Auto-advance after brief display
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(studySessionProvider.notifier).rateCard(4);
            setState(() {
              _currentWordId = null;
              _options = [];
            });
          }
        });
      }
      return;
    }

    // Pick one correct reading randomly
    final correctReading = (List<String>.from(allReadings)..shuffle()).first;

    // Get distractor readings from other kanji
    final wordRepo = WordRepository();
    final distractors = await wordRepo.getReadingDistractors(
      correctReading: correctReading,
      wordListId: correctWord.wordListId,
      excludeWordId: correctWord.id!,
      count: 3,
    );

    // Ensure we have at least some options
    // If no distractors, use other readings from the same kanji
    List<String> options;
    if (distractors.isEmpty && allReadings.length > 1) {
      // Use other readings from the same kanji as distractors
      final otherReadings = allReadings.where((r) => r != correctReading).take(3).toList();
      options = [correctReading, ...otherReadings];
    } else {
      options = [correctReading, ...distractors];
    }
    options.shuffle();

    if (mounted) {
      setState(() {
        _currentWordId = correctWord.id;
        _options = options;
        _correctReading = correctReading;
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

    // Speak the correct reading
    if (_correctReading.isNotEmpty) {
      final tts = ref.read(ttsServiceProvider);
      tts.speak(_correctReading, language: 'ja');
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
