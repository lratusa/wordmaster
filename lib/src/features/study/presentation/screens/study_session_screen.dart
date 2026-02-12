import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../common_widgets/furigana_text.dart';
import '../../../word_lists/domain/enums/language.dart';
import '../../application/study_session_notifier.dart';

typedef SpeakCallback = void Function(String text, String language);

class StudySessionScreen extends ConsumerWidget {
  const StudySessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studySessionProvider);

    if (session.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isCompleted) {
      // Navigate to summary
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${session.currentIndex + 1} / ${session.totalWords}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(context),
        ),
        actions: [
          // TTS button
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              final tts = ref.read(ttsServiceProvider);
              tts.speak(item.word.word, language: item.word.language.code);
            },
          ),
          // Star button
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

          // Flashcard area
          Expanded(
            child: _FlashCard(
              item: item,
              isAnswerShown: session.isAnswerShown,
              onTap: () {
                if (!session.isAnswerShown) {
                  ref.read(studySessionProvider.notifier).showAnswer();
                }
              },
              onSpeak: (text, language) {
                ref.read(ttsServiceProvider).speak(text, language: language);
              },
            ),
          ),

          // Rating buttons (shown after answer revealed)
          if (session.isAnswerShown)
            _RatingBar(
              onRate: (rating) {
                ref.read(studySessionProvider.notifier).rateCard(rating);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () =>
                      ref.read(studySessionProvider.notifier).showAnswer(),
                  child: const Text('显示答案', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
        ],
      ),
    );
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
              context.go('/');
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _FlashCard extends StatefulWidget {
  final StudyItem item;
  final bool isAnswerShown;
  final VoidCallback onTap;
  final SpeakCallback onSpeak;

  const _FlashCard({
    required this.item,
    required this.isAnswerShown,
    required this.onTap,
    required this.onSpeak,
  });

  @override
  State<_FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<_FlashCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_showBack) {
        setState(() => _showBack = true);
      } else if (_controller.value < 0.5 && _showBack) {
        setState(() => _showBack = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FlashCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnswerShown && !oldWidget.isAnswerShown) {
      _controller.forward();
      // Auto-play word pronunciation when answer is revealed
      final word = widget.item.word;
      widget.onSpeak(word.word, word.language.code);
    }
    if (!widget.isAnswerShown && oldWidget.isAnswerShown) {
      _controller.reverse();
      _showBack = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBack = _animation.value >= 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBackSide(),
                  )
                : _buildFrontSide(),
          );
        },
      ),
    );
  }

  Widget _buildFrontSide() {
    final word = widget.item.word;
    final isJapanese = word.language == Language.ja;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.item.isNewWord)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            const SizedBox(height: 24),
            Text(
              '点击查看答案',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackSide() {
    final word = widget.item.word;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Word at top with speaker button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    word.word,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 24),
                  onPressed: () =>
                      widget.onSpeak(word.word, word.language.code),
                  color: AppColors.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Translation
            Text(
              word.translationCn,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            // Example sentences
            if (word.exampleSentences.isNotEmpty) ...[
              const Divider(height: 32),
              ...word.exampleSentences.map((ex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              ex.sentence,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => widget.onSpeak(
                                ex.sentence, word.language.code),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4, top: 2),
                              child: Icon(Icons.volume_up,
                                  size: 18, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ex.translationCn,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final void Function(int rating) onRate;

  const _RatingBar({required this.onRate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildRatingButton(
              context,
              rating: 1,
              label: '忘记',
              color: AppColors.ratingAgain,
            ),
            const SizedBox(width: 8),
            _buildRatingButton(
              context,
              rating: 2,
              label: '困难',
              color: AppColors.ratingHard,
            ),
            const SizedBox(width: 8),
            _buildRatingButton(
              context,
              rating: 3,
              label: '记得',
              color: AppColors.ratingGood,
            ),
            const SizedBox(width: 8),
            _buildRatingButton(
              context,
              rating: 4,
              label: '简单',
              color: AppColors.ratingEasy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(
    BuildContext context, {
    required int rating,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: () => onRate(rating),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
