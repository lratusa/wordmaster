import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../data/repositories/settings_repository.dart';

/// App settings state.
class AppSettings {
  final String aiBackend; // openai, deepseek, ollama, manual
  final String apiKey;
  final String ollamaUrl;
  final String ollamaModel;
  final double ttsSpeed;
  final ThemeMode themeMode;
  final int dailyNewWordsGoal;
  final int dailyReviewLimit;

  const AppSettings({
    this.aiBackend = 'manual',
    this.apiKey = '',
    this.ollamaUrl = 'http://localhost:11434',
    this.ollamaModel = 'qwen2.5:7b',
    this.ttsSpeed = 0.5,
    this.themeMode = ThemeMode.system,
    this.dailyNewWordsGoal = AppConstants.defaultNewWordsPerDay,
    this.dailyReviewLimit = AppConstants.defaultReviewLimitPerDay,
  });

  AppSettings copyWith({
    String? aiBackend,
    String? apiKey,
    String? ollamaUrl,
    String? ollamaModel,
    double? ttsSpeed,
    ThemeMode? themeMode,
    int? dailyNewWordsGoal,
    int? dailyReviewLimit,
  }) {
    return AppSettings(
      aiBackend: aiBackend ?? this.aiBackend,
      apiKey: apiKey ?? this.apiKey,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      themeMode: themeMode ?? this.themeMode,
      dailyNewWordsGoal: dailyNewWordsGoal ?? this.dailyNewWordsGoal,
      dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  final _repo = SettingsRepository();

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final all = await _repo.getAll();

    state = AppSettings(
      aiBackend: all[SettingKeys.aiBackend] ?? 'manual',
      apiKey: all[SettingKeys.apiKey] ?? '',
      ollamaUrl: all[SettingKeys.ollamaUrl] ?? 'http://localhost:11434',
      ollamaModel: all[SettingKeys.ollamaModel] ?? 'qwen2.5:7b',
      ttsSpeed: double.tryParse(all[SettingKeys.ttsSpeed] ?? '') ?? 0.5,
      themeMode: _parseThemeMode(all[SettingKeys.themeMode]),
      dailyNewWordsGoal: int.tryParse(all[SettingKeys.dailyNewWordsGoal] ?? '') ??
          AppConstants.defaultNewWordsPerDay,
      dailyReviewLimit: int.tryParse(all[SettingKeys.dailyReviewLimit] ?? '') ??
          AppConstants.defaultReviewLimitPerDay,
    );
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setAiBackend(String backend) async {
    await _repo.set(SettingKeys.aiBackend, backend);
    state = state.copyWith(aiBackend: backend);
  }

  Future<void> setApiKey(String key) async {
    await _repo.set(SettingKeys.apiKey, key);
    state = state.copyWith(apiKey: key);
  }

  Future<void> setOllamaUrl(String url) async {
    await _repo.set(SettingKeys.ollamaUrl, url);
    state = state.copyWith(ollamaUrl: url);
  }

  Future<void> setOllamaModel(String model) async {
    await _repo.set(SettingKeys.ollamaModel, model);
    state = state.copyWith(ollamaModel: model);
  }

  Future<void> setTtsSpeed(double speed) async {
    await _repo.set(SettingKeys.ttsSpeed, speed.toString());
    state = state.copyWith(ttsSpeed: speed);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.set(SettingKeys.themeMode, _themeModeToString(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDailyNewWordsGoal(int goal) async {
    await _repo.set(SettingKeys.dailyNewWordsGoal, goal.toString());
    state = state.copyWith(dailyNewWordsGoal: goal);
  }

  Future<void> setDailyReviewLimit(int limit) async {
    await _repo.set(SettingKeys.dailyReviewLimit, limit.toString());
    state = state.copyWith(dailyReviewLimit: limit);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
