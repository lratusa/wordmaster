import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/download_mirror.dart';
import '../../../../core/services/tts_model_downloader.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../study/application/study_session_notifier.dart';
import '../../../word_lists/data/repositories/word_list_repository.dart';
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
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text('TTS 语音模型'),
              subtitle: const Text('下载离线语音包'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TtsModelScreen()),
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

          // Personalization
          _buildSection(context, '个性化', [
            ListTile(
              leading: _buildAvatarIcon(settings.avatarIndex),
              title: const Text('头像'),
              subtitle: const Text('选择你的头像'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAvatarDialog(context, notifier, settings.avatarIndex),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('昵称'),
              subtitle: Text(settings.nickname.isEmpty ? '未设置' : settings.nickname),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTextInputDialog(
                context,
                title: '设置昵称',
                currentValue: settings.nickname,
                hint: '输入你的昵称',
                onSave: notifier.setNickname,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('学习目标'),
              subtitle: Text(settings.studyMotivation.isEmpty
                  ? '未设置'
                  : settings.studyMotivation),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showMotivationDialog(context, notifier, settings.studyMotivation),
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

          // Download Source
          _buildSection(context, '下载源', [
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('词书下载源'),
              subtitle: Text(settings.wordlistDownloadRegion == DownloadRegion.china
                  ? '国内镜像'
                  : '国际 (GitHub)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRegionDialog(
                context,
                title: '词书下载源',
                current: settings.wordlistDownloadRegion,
                onSelect: notifier.setWordlistDownloadRegion,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text('语音包下载源'),
              subtitle: Text(settings.ttsDownloadRegion == DownloadRegion.china
                  ? '国内镜像'
                  : '国际 (GitHub)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRegionDialog(
                context,
                title: '语音包下载源',
                current: settings.ttsDownloadRegion,
                onSelect: notifier.setTtsDownloadRegion,
              ),
            ),
            if (settings.wordlistDownloadRegion == DownloadRegion.china ||
                settings.ttsDownloadRegion == DownloadRegion.china)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '提示：中国大陆用户建议选择"国内镜像"以获得更快的下载速度。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            if (settings.aiBackend == 'openai' &&
                (settings.wordlistDownloadRegion == DownloadRegion.china ||
                    settings.ttsDownloadRegion == DownloadRegion.china))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '注意：OpenAI 在中国大陆无法访问，建议将 AI 服务切换为 DeepSeek 或 Ollama。',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
          ]),

          // Data Management
          _buildSection(context, '数据管理', [
            ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.warning),
              title: const Text('重置词单'),
              subtitle: const Text('清除所有词单数据并重新导入内置词单'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showResetWordListsDialog(context),
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

  void _showResetWordListsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.warning),
            SizedBox(width: 8),
            Text('重置词单'),
          ],
        ),
        content: const Text(
          '此操作将删除所有词单数据（包括学习进度），并重新导入内置词单。\n\n'
          '此操作不可撤销，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('正在重置词单...'),
                    ],
                  ),
                ),
              );

              try {
                final repo = WordListRepository();
                await repo.resetAllWordLists();

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('词单已重置'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('重置失败: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('确定重置'),
          ),
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

  /// Available avatars for user selection
  static const List<IconData> _avatarIcons = [
    Icons.face,
    Icons.face_2,
    Icons.face_3,
    Icons.face_4,
    Icons.face_5,
    Icons.face_6,
    Icons.school,
    Icons.auto_stories,
    Icons.psychology,
    Icons.lightbulb,
    Icons.rocket_launch,
    Icons.star,
  ];

  /// Available study motivations
  static const List<String> _motivations = [
    '考研',
    '四六级',
    '托福/雅思',
    'GRE/GMAT',
    '工作需要',
    '出国留学',
    '日常交流',
    '兴趣爱好',
    '自我提升',
  ];

  Widget _buildAvatarIcon(int index) {
    final iconData = index >= 0 && index < _avatarIcons.length
        ? _avatarIcons[index]
        : _avatarIcons[0];
    return CircleAvatar(
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: Icon(iconData, color: AppColors.primary),
    );
  }

  void _showAvatarDialog(
    BuildContext context,
    SettingsNotifier notifier,
    int currentIndex,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择头像'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _avatarIcons.length,
            itemBuilder: (context, index) {
              final isSelected = index == currentIndex;
              return InkWell(
                onTap: () {
                  notifier.setAvatarIndex(index);
                  Navigator.of(ctx).pop();
                },
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.1),
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Icon(
                    _avatarIcons[index],
                    color: isSelected ? Colors.white : AppColors.primary,
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showMotivationDialog(
    BuildContext context,
    SettingsNotifier notifier,
    String currentMotivation,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('学习目标'),
        children: [
          ..._motivations.map((motivation) {
            final isSelected = motivation == currentMotivation;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppColors.success : null,
              ),
              title: Text(motivation),
              onTap: () {
                notifier.setStudyMotivation(motivation);
                Navigator.of(ctx).pop();
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('自定义'),
            onTap: () {
              Navigator.of(ctx).pop();
              _showTextInputDialog(
                context,
                title: '自定义学习目标',
                currentValue: currentMotivation,
                hint: '输入你的学习目标',
                onSave: notifier.setStudyMotivation,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRegionDialog(
    BuildContext context, {
    required String title,
    required DownloadRegion current,
    required Future<void> Function(DownloadRegion) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          RadioListTile<DownloadRegion>(
            value: DownloadRegion.international,
            groupValue: current,
            title: const Text('国际 (GitHub)'),
            subtitle: const Text('适合海外用户', style: TextStyle(fontSize: 12)),
            onChanged: (v) {
              if (v != null) {
                onSelect(v);
                Navigator.of(ctx).pop();
              }
            },
          ),
          RadioListTile<DownloadRegion>(
            value: DownloadRegion.china,
            groupValue: current,
            title: const Text('国内镜像'),
            subtitle: const Text('适合中国大陆用户，下载更快更稳定', style: TextStyle(fontSize: 12)),
            onChanged: (v) {
              if (v != null) {
                onSelect(v);
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

/// TTS Model download screen
class TtsModelScreen extends ConsumerStatefulWidget {
  const TtsModelScreen({super.key});

  @override
  ConsumerState<TtsModelScreen> createState() => _TtsModelScreenState();
}

class _TtsModelScreenState extends ConsumerState<TtsModelScreen> {
  final TtsModelDownloader _downloader = TtsModelDownloader();
  final Map<String, bool> _downloadedModels = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  final Map<String, bool> _isExtracting = {};
  String? _activeModelId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    for (final model in TtsModelDownloader.availableModels) {
      _downloadedModels[model.id] = await _downloader.isModelDownloaded(model.id);
      _isDownloading[model.id] = false;
      _isExtracting[model.id] = false;
    }
    _activeModelId = await _downloader.getActiveModelId();

    setState(() => _isLoading = false);
  }

  Future<void> _downloadModel(TtsModel model) async {
    setState(() {
      _isDownloading[model.id] = true;
      _downloadProgress[model.id] = 0;
    });

    try {
      final ttsRegion = ref.read(settingsProvider).ttsDownloadRegion;
      await _downloader.downloadModel(
        model,
        onProgress: (received, total) {
          setState(() {
            _downloadProgress[model.id] = received / total;
          });
        },
        onExtracting: () {
          setState(() {
            _isExtracting[model.id] = true;
          });
        },
        region: ttsRegion,
      );

      setState(() {
        _downloadedModels[model.id] = true;
        _isDownloading[model.id] = false;
        _isExtracting[model.id] = false;
      });

      // Auto-activate if no model is active
      if (_activeModelId == null) {
        await _activateModel(model.id);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.name} 下载完成，点击菜单选择"使用此语音"来激活')),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading[model.id] = false;
        _isExtracting[model.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  Future<void> _activateModel(String modelId) async {
    await _downloader.setActiveModel(modelId);
    setState(() {
      _activeModelId = modelId;
    });

    // Reset TTS service to pick up the new model
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.reset();
    await ttsService.initialize();

    if (mounted) {
      if (ttsService.isReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音模型已激活，可以正常使用')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('语音模型激活失败: ${ttsService.lastError ?? "未知错误"}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Refresh UI to show updated status
      setState(() {});
    }
  }

  Future<void> _deleteModel(TtsModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除语音包'),
        content: Text('确定要删除 ${model.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloader.deleteModel(model.id);
      setState(() {
        _downloadedModels[model.id] = false;
        if (_activeModelId == model.id) {
          _activeModelId = null;
        }
      });
    }
  }

  Widget _buildTtsStatusCard() {
    final ttsService = ref.read(ttsServiceProvider);
    final isReady = ttsService.isReady;
    final status = ttsService.status;

    return Card(
      color: isReady
          ? AppColors.success.withValues(alpha: 0.1)
          : _activeModelId != null
              ? AppColors.warning.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isReady
                      ? Icons.check_circle
                      : _activeModelId != null
                          ? Icons.warning
                          : Icons.info_outline,
                  color: isReady
                      ? AppColors.success
                      : _activeModelId != null
                          ? AppColors.warning
                          : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isReady ? '语音已就绪' : '语音状态',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isReady
                  ? '离线语音功能正常工作'
                  : _activeModelId == null
                      ? '请下载并激活一个语音包'
                      : '状态: $status',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_activeModelId != null && !isReady)
                  TextButton.icon(
                    onPressed: () async {
                      ttsService.reset();
                      await ttsService.initialize();
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ttsService.isReady
                                ? '语音初始化成功'
                                : '语音初始化失败: ${ttsService.lastError ?? "未知错误"}'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新初始化'),
                  ),
                if (isReady)
                  TextButton.icon(
                    onPressed: () async {
                      await ttsService.speak('Hello, this is a test of the text to speech system.');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('正在播放测试语音...')),
                        );
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('测试语音'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TTS 语音模型')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              '离线语音',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '下载语音包后可离线朗读单词，无需联网。\n'
                          '选择适合您学习语言的语音包。',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // TTS Status card
                _buildTtsStatusCard(),
                const SizedBox(height: 16),

                // Model list
                ...TtsModelDownloader.availableModels.map((model) {
                  final isDownloaded = _downloadedModels[model.id] ?? false;
                  final isDownloading = _isDownloading[model.id] ?? false;
                  final isExtracting = _isExtracting[model.id] ?? false;
                  final progress = _downloadProgress[model.id] ?? 0;
                  final isActive = _activeModelId == model.id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? AppColors.success
                            : isDownloaded
                                ? AppColors.primary
                                : Colors.grey[300],
                        child: Icon(
                          isActive
                              ? Icons.check
                              : isDownloaded
                                  ? Icons.volume_up
                                  : Icons.download,
                          color: Colors.white,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(model.name)),
                          if (model.supportsJapanese) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '日语',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '使用中',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: isDownloading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: progress),
                                const SizedBox(height: 4),
                                Text(
                                  isExtracting
                                      ? '解压中...'
                                      : '下载中 ${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            )
                          : Text(
                              isDownloaded ? '已下载' : '约 ${model.sizeDisplay}',
                            ),
                      trailing: isDownloading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : isDownloaded
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'activate') {
                                      _activateModel(model.id);
                                    } else if (value == 'delete') {
                                      _deleteModel(model);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (!isActive)
                                      const PopupMenuItem(
                                        value: 'activate',
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle_outline),
                                            SizedBox(width: 8),
                                            Text('使用此语音'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('删除',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadModel(model),
                                ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
