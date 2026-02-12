import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/audio_review_notifier.dart';

class AudioReviewScreen extends ConsumerWidget {
  const AudioReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioReviewProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isCompleted) {
      // Check if there's an error message (e.g., unsupported language)
      if (state.errorMessage != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('听力练习')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.volume_off,
                    size: 64,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('返回首页'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/study/summary');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final item = state.currentItem;
    if (item == null) {
      return const Scaffold(
        body: Center(child: Text('没有可练习的单词')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${state.currentIndex + 1} / ${state.totalWords}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(audioReviewProvider.notifier).stopSession();
            context.go('/');
          },
        ),
        actions: [
          if (state.mode == AudioMode.auto)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '自动',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: state.totalWords > 0
                ? state.currentIndex / state.totalWords
                : 0,
            minHeight: 3,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large speaker icon - tap to replay
                    GestureDetector(
                      onTap: () =>
                          ref.read(audioReviewProvider.notifier).replay(),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          state.isPlaying
                              ? Icons.volume_up
                              : Icons.volume_up_outlined,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Show playback phase
                    if (state.isPlaying)
                      Text(
                        state.playbackPhase == PlaybackPhase.playingWord
                            ? '正在播放单词...'
                            : state.playbackPhase == PlaybackPhase.playingSentence
                                ? '正在播放例句...'
                                : '播放中...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        '点击重新播放',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Answer area
                    if (state.isAnswerRevealed) ...[
                      Text(
                        item.word.word,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.word.phonetic != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.word.phonetic!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (item.word.reading != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.word.reading!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        item.word.translationCn,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        '???',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: state.isAnswerRevealed
                  ? Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () => ref
                                  .read(audioReviewProvider.notifier)
                                  .rate(false),
                              icon: const Icon(Icons.close),
                              label: const Text('不认识',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ratingAgain
                                    .withValues(alpha: 0.15),
                                foregroundColor: AppColors.ratingAgain,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () => ref
                                  .read(audioReviewProvider.notifier)
                                  .rate(true),
                              icon: const Icon(Icons.check),
                              label: const Text('认识',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ratingGood
                                    .withValues(alpha: 0.15),
                                foregroundColor: AppColors.ratingGood,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => ref
                            .read(audioReviewProvider.notifier)
                            .revealAnswer(),
                        child: const Text('显示答案',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
