import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/core/services/download_mirror.dart';
import 'package:wordmaster/src/features/settings/data/repositories/settings_repository.dart';

import '../repository/test_database_helper.dart';

void main() {
  late Database db;
  late SettingsRepository repo;

  setUp(() async {
    db = await createTestDatabase();
    repo = SettingsRepository();
  });

  tearDown(() async {
    await db.close();
  });

  group('Settings Persistence Integration', () {
    test('all SettingKeys round-trip correctly', () async {
      final settings = {
        SettingKeys.aiBackend: 'deepseek',
        SettingKeys.apiKey: 'sk-test-key-12345',
        SettingKeys.ollamaUrl: 'http://localhost:11434',
        SettingKeys.ollamaModel: 'llama3',
        SettingKeys.ttsSpeed: '1.2',
        SettingKeys.themeMode: 'dark',
        SettingKeys.dailyNewWordsGoal: '20',
        SettingKeys.dailyReviewLimit: '100',
        SettingKeys.nickname: '小明',
        SettingKeys.avatarIndex: '3',
        SettingKeys.studyMotivation: '考试',
        SettingKeys.wordlistDownloadRegion: 'china',
        SettingKeys.ttsDownloadRegion: 'international',
      };

      // Write all settings
      for (final entry in settings.entries) {
        await repo.set(entry.key, entry.value);
      }

      // Read them all back
      for (final entry in settings.entries) {
        final value = await repo.get(entry.key);
        expect(value, entry.value, reason: 'Key ${entry.key} should roundtrip');
      }

      // Verify getAll contains everything
      final all = await repo.getAll();
      expect(all.length, settings.length);
    });

    test('Unicode nickname round-trips', () async {
      await repo.set(SettingKeys.nickname, '学习者🎯');
      final value = await repo.get(SettingKeys.nickname);
      expect(value, '学习者🎯');
    });

    test('Japanese text round-trips', () async {
      await repo.set(SettingKeys.studyMotivation, '日本語を勉強したい');
      final value = await repo.get(SettingKeys.studyMotivation);
      expect(value, '日本語を勉強したい');
    });

    test('region settings integrate with DownloadMirror', () async {
      await repo.set(SettingKeys.wordlistDownloadRegion, 'china');
      await repo.set(SettingKeys.ttsDownloadRegion, 'international');

      final wlRegionStr = await repo.get(SettingKeys.wordlistDownloadRegion);
      final ttsRegionStr = await repo.get(SettingKeys.ttsDownloadRegion);

      final wlRegion = DownloadMirror.parseRegion(wlRegionStr);
      final ttsRegion = DownloadMirror.parseRegion(ttsRegionStr);

      expect(wlRegion, DownloadRegion.china);
      expect(ttsRegion, DownloadRegion.international);

      final wlUrl = DownloadMirror.wordlistBaseUrl(wlRegion);
      expect(wlUrl, contains('47.93.144.50'));

      final ttsUrl = DownloadMirror.ttsBaseUrl(ttsRegion);
      expect(ttsUrl, contains('github'));
    });

    test('overwriting settings preserves only latest value', () async {
      await repo.set(SettingKeys.themeMode, 'light');
      await repo.set(SettingKeys.themeMode, 'dark');
      await repo.set(SettingKeys.themeMode, 'system');

      final value = await repo.get(SettingKeys.themeMode);
      expect(value, 'system');

      final all = await repo.getAll();
      final themeModeEntries = all.entries.where((e) => e.key == SettingKeys.themeMode);
      expect(themeModeEntries.length, 1);
    });

    test('deleting a setting removes only that key', () async {
      await repo.set(SettingKeys.nickname, 'Test');
      await repo.set(SettingKeys.themeMode, 'dark');
      await repo.set(SettingKeys.ttsSpeed, '1.0');

      await repo.delete(SettingKeys.nickname);

      expect(await repo.get(SettingKeys.nickname), isNull);
      expect(await repo.get(SettingKeys.themeMode), 'dark');
      expect(await repo.get(SettingKeys.ttsSpeed), '1.0');
    });
  });
}
