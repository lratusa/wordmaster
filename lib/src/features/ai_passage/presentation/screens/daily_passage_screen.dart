import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../study/application/study_session_notifier.dart';
import '../../application/ai_passage_notifier.dart';

class DailyPassageScreen extends ConsumerStatefulWidget {
  const DailyPassageScreen({super.key});

  @override
  ConsumerState<DailyPassageScreen> createState() =>
      _DailyPassageScreenState();
}

class _DailyPassageScreenState extends ConsumerState<DailyPassageScreen> {
  String _selectedLanguage = 'en';
  final _pasteController = TextEditingController();

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPassageProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 短文'),
        actions: [
          if (state.passage != null)
            IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () {
                final tts = ref.read(ttsServiceProvider);
                tts.speak(state.passage!.passage, language: state.language);
              },
            ),
        ],
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(AiPassageState state, ThemeData theme) {
    // Initial state - language selection
    if (!state.isLoading &&
        state.passage == null &&
        state.promptText == null &&
        state.error == null) {
      return _buildLanguageSelector(theme);
    }

    // Loading
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI 正在生成短文...'),
          ],
        ),
      );
    }

    // Error
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref
                    .read(aiPassageProvider.notifier)
                    .generatePassage(_selectedLanguage),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // Manual mode - show prompt for copy-paste
    if (state.isManualMode && state.promptText != null) {
      return _buildManualMode(state, theme);
    }

    // Passage loaded
    if (state.passage != null) {
      return _buildPassageView(state, theme);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLanguageSelector(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.auto_stories, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'AI 将根据你学过的单词\n生成一篇短文和理解题',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          Text(
            '选择语言',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLanguageCard(
                  label: 'English',
                  subtitle: '英语短文',
                  icon: Icons.school,
                  color: AppColors.englishBadge,
                  language: 'en',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageCard(
                  label: '日本語',
                  subtitle: '日语短文',
                  icon: Icons.language,
                  color: AppColors.japaneseBadge,
                  language: 'ja',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => ref
                  .read(aiPassageProvider.notifier)
                  .generatePassage(_selectedLanguage),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('生成短文', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '未配置 API？无需担心，可直接复制提示词到任意 AI 对话工具使用',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String language,
  }) {
    final isSelected = _selectedLanguage == language;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = language),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualMode(AiPassageState state, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.info.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 8),
                      Text(
                        '未配置 API',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请复制下方提示词，粘贴到任意 AI 对话工具（如 ChatGPT、Claude、豆包等），'
                    '然后将 AI 的回复粘贴到下方输入框中。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '提示词（点击复制）',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: state.promptText!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.promptText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '粘贴 AI 回复',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pasteController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '将 AI 返回的 JSON 粘贴到这里...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                if (_pasteController.text.trim().isNotEmpty) {
                  ref
                      .read(aiPassageProvider.notifier)
                      .parseManualResponse(_pasteController.text);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('解析并生成'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageView(AiPassageState state, ThemeData theme) {
    final passage = state.passage!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passage card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passage.passage,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(height: 1.8),
                  ),
                  if (passage.translation.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(
                      passage.translation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quiz button
          if (passage.questions.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.go('/ai-passage/quiz'),
                icon: const Icon(Icons.quiz),
                label: Text(
                  '开始理解测验（${passage.questions.length} 题）',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
