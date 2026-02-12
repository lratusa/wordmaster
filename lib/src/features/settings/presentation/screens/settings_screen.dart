import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/settings_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // AI Settings
          _buildSection(context, 'AI 短文设置', [
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('AI 服务'),
              subtitle: Text(_aiBackendLabel(settings.aiBackend)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAiBackendDialog(context, notifier, settings.aiBackend),
            ),
            if (settings.aiBackend == 'openai' || settings.aiBackend == 'deepseek')
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('API Key'),
                subtitle: Text(
                  settings.apiKey.isEmpty
                      ? '未设置'
                      : '${settings.apiKey.substring(0, 8.clamp(0, settings.apiKey.length))}...',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTextInputDialog(
                  context,
                  title: 'API Key',
                  currentValue: settings.apiKey,
                  hint: '输入 API Key',
                  obscure: true,
                  onSave: notifier.setApiKey,
                ),
              ),
            if (settings.aiBackend == 'ollama') ...[
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Ollama 地址'),
                subtitle: Text(settings.ollamaUrl),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTextInputDialog(
                  context,
                  title: 'Ollama 地址',
                  currentValue: settings.ollamaUrl,
                  hint: 'http://localhost:11434',
                  onSave: notifier.setOllamaUrl,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.memory),
                title: const Text('Ollama 模型'),
                subtitle: Text(settings.ollamaModel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTextInputDialog(
                  context,
                  title: 'Ollama 模型名称',
                  currentValue: settings.ollamaModel,
                  hint: 'qwen2.5:7b',
                  onSave: notifier.setOllamaModel,
                ),
              ),
            ],
          ]),

          // TTS Settings
          _buildSection(context, '语音设置', [
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('语音速度'),
              subtitle: Slider(
                value: settings.ttsSpeed,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: _ttsSpeedLabel(settings.ttsSpeed),
                onChanged: (v) => notifier.setTtsSpeed(v),
              ),
              trailing: Text(
                _ttsSpeedLabel(settings.ttsSpeed),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ]),

          // Study Settings
          _buildSection(context, '学习设置', [
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('每日新词目标'),
              subtitle: Slider(
                value: settings.dailyNewWordsGoal.toDouble(),
                min: 5,
                max: 50,
                divisions: 9,
                label: '${settings.dailyNewWordsGoal}',
                onChanged: (v) => notifier.setDailyNewWordsGoal(v.round()),
              ),
              trailing: Text(
                '${settings.dailyNewWordsGoal}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('每日复习上限'),
              subtitle: Slider(
                value: settings.dailyReviewLimit.toDouble(),
                min: 50,
                max: 500,
                divisions: 9,
                label: '${settings.dailyReviewLimit}',
                onChanged: (v) => notifier.setDailyReviewLimit(v.round()),
              ),
              trailing: Text(
                '${settings.dailyReviewLimit}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ]),

          // Appearance
          _buildSection(context, '外观', [
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('主题模式'),
              subtitle: Text(_themeModeLabel(settings.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeModeDialog(context, notifier, settings.themeMode),
            ),
          ]),

          // About
          _buildSection(context, '关于', [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('WordMaster'),
              subtitle: Text('v1.0.0 · AI驱动 · 艾宾浩斯记忆 · 英日双语'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  String _aiBackendLabel(String backend) {
    switch (backend) {
      case 'openai':
        return 'OpenAI';
      case 'deepseek':
        return 'DeepSeek';
      case 'ollama':
        return 'Ollama (本地)';
      default:
        return '手动模式 (复制粘贴)';
    }
  }

  String _ttsSpeedLabel(double speed) {
    if (speed <= 0.3) return '很慢';
    if (speed <= 0.45) return '慢';
    if (speed <= 0.55) return '正常';
    if (speed <= 0.75) return '快';
    return '很快';
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  void _showAiBackendDialog(
    BuildContext context,
    SettingsNotifier notifier,
    String current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择 AI 服务'),
        children: [
          _buildRadioOption(ctx, 'manual', '手动模式 (复制粘贴)',
              '无需 API，生成 Prompt 后手动粘贴到任意 AI', current, notifier.setAiBackend),
          _buildRadioOption(ctx, 'openai', 'OpenAI',
              '需要 API Key，推荐 gpt-4o-mini', current, notifier.setAiBackend),
          _buildRadioOption(ctx, 'deepseek', 'DeepSeek',
              '需要 API Key，性价比高', current, notifier.setAiBackend),
          _buildRadioOption(ctx, 'ollama', 'Ollama (本地)',
              '本地运行，无需网络，需安装 Ollama', current, notifier.setAiBackend),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
    BuildContext context,
    String value,
    String title,
    String subtitle,
    String current,
    Future<void> Function(String) onSelect,
  ) {
    return RadioListTile<String>(
      value: value,
      groupValue: current,
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onChanged: (v) {
        if (v != null) {
          onSelect(v);
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showThemeModeDialog(
    BuildContext context,
    SettingsNotifier notifier,
    ThemeMode current,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('主题模式'),
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: current,
            title: const Text('跟随系统'),
            onChanged: (v) {
              if (v != null) {
                notifier.setThemeMode(v);
                Navigator.of(ctx).pop();
              }
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: current,
            title: const Text('浅色模式'),
            onChanged: (v) {
              if (v != null) {
                notifier.setThemeMode(v);
                Navigator.of(ctx).pop();
              }
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: current,
            title: const Text('深色模式'),
            onChanged: (v) {
              if (v != null) {
                notifier.setThemeMode(v);
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showTextInputDialog(
    BuildContext context, {
    required String title,
    required String currentValue,
    required String hint,
    bool obscure = false,
    required Future<void> Function(String) onSave,
  }) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
