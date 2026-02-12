import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/ai_passage_notifier.dart';

class PassageQuizScreen extends ConsumerWidget {
  const PassageQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPassageProvider);
    final theme = Theme.of(context);

    if (state.passage == null || state.passage!.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('阅读理解')),
        body: const Center(child: Text('没有可用的题目')),
      );
    }

    final questions = state.passage!.questions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读理解'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/ai-passage'),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length + (state.isQuizComplete ? 1 : 0),
        itemBuilder: (context, index) {
          // Score card at the end
          if (index == questions.length) {
            return _buildScoreCard(state, theme);
          }

          final question = questions[index];
          final userAnswer = state.userAnswers[index];
          final isAnswered = userAnswer != null;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${question.question}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(question.options.length, (optIdx) {
                    final isSelected = userAnswer == optIdx;
                    final isCorrect =
                        optIdx == question.correctIndex;

                    Color? bgColor;
                    Color? textColor;
                    if (isAnswered) {
                      if (isCorrect) {
                        bgColor =
                            AppColors.success.withValues(alpha: 0.1);
                        textColor = AppColors.success;
                      } else if (isSelected && !isCorrect) {
                        bgColor =
                            AppColors.ratingAgain.withValues(alpha: 0.1);
                        textColor = AppColors.ratingAgain;
                      }
                    } else if (isSelected) {
                      bgColor = AppColors.primary.withValues(alpha: 0.1);
                      textColor = AppColors.primary;
                    }

                    return GestureDetector(
                      onTap: isAnswered
                          ? null
                          : () => ref
                              .read(aiPassageProvider.notifier)
                              .answerQuestion(index, optIdx),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: textColor ??
                                theme.colorScheme.outline
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              String.fromCharCode(65 + optIdx),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                question.options[optIdx],
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            if (isAnswered && isCorrect)
                              const Icon(Icons.check_circle,
                                  color: AppColors.success, size: 20),
                            if (isAnswered && isSelected && !isCorrect)
                              const Icon(Icons.cancel,
                                  color: AppColors.ratingAgain, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (isAnswered && question.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 18, color: AppColors.info),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question.explanation,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreCard(AiPassageState state, ThemeData theme) {
    final total = state.passage!.questions.length;
    final correct = state.score ?? 0;
    final percentage = total > 0 ? (correct / total * 100).round() : 0;

    return Card(
      color: percentage >= 80
          ? AppColors.success.withValues(alpha: 0.1)
          : percentage >= 60
              ? AppColors.warning.withValues(alpha: 0.1)
              : AppColors.ratingAgain.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              percentage >= 80
                  ? Icons.emoji_events
                  : percentage >= 60
                      ? Icons.thumb_up
                      : Icons.sentiment_neutral,
              size: 48,
              color: percentage >= 80
                  ? AppColors.checkinGold
                  : percentage >= 60
                      ? AppColors.success
                      : AppColors.warning,
            ),
            const SizedBox(height: 12),
            Text(
              '$correct / $total 正确 ($percentage%)',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              percentage >= 80
                  ? '太棒了！理解非常好！'
                  : percentage >= 60
                      ? '不错！继续加油！'
                      : '再多读几遍短文吧！',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
