import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/application/settings_notifier.dart';
import '../../application/greeting_provider.dart';

/// A beautifully designed greeting card for the home screen
class GreetingCard extends ConsumerWidget {
  final int streakDays;
  final int todayWords;
  final int totalWords;
  final int dailyGoal;

  const GreetingCard({
    super.key,
    required this.streakDays,
    required this.todayWords,
    required this.totalWords,
    required this.dailyGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final greetingData = ref.watch(greetingProvider);
    final greetingNotifier = ref.read(greetingProvider.notifier);

    final nickname = settings.nickname;
    final studyMotivation = settings.studyMotivation;

    final encouragement = greetingNotifier.formatEncouragement(
      greetingData.encouragement,
      streak: streakDays,
      todayWords: todayWords,
      totalWords: totalWords,
      dailyGoal: dailyGoal,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primaryColor.withValues(alpha: 0.2),
                  primaryColor.withValues(alpha: 0.1),
                ]
              : [
                  primaryColor.withValues(alpha: 0.15),
                  primaryColor.withValues(alpha: 0.05),
                ],
        ),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting row with icon and optional short motivation tag
            Row(
              children: [
                Text(
                  greetingData.icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nickname.isNotEmpty
                        ? '${greetingData.greeting}，$nickname'
                        : greetingData.greeting,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Short motivation as a tag (< 6 characters)
                if (studyMotivation.isNotEmpty && studyMotivation.length < 6)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      studyMotivation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
              ],
            ),

            // Study motivation quote box (only for longer motivations >= 6 characters)
            if (studyMotivation.isNotEmpty && studyMotivation.length >= 6) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '"',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor.withValues(alpha: 0.5),
                        height: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        studyMotivation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '"',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor.withValues(alpha: 0.5),
                        height: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Encouragement line
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    encouragement,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
