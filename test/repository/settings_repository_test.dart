import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wordmaster/src/features/settings/data/repositories/settings_repository.dart';

import 'test_database_helper.dart';

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

  group('SettingsRepository', () {
    test('get returns null for non-existent key', () async {
      final value = await repo.get('non_existent');
      expect(value, isNull);
    });

    test('set and get roundtrip', () async {
      await repo.set('theme_mode', 'dark');
      final value = await repo.get('theme_mode');
      expect(value, 'dark');
    });

    test('set overwrites existing value', () async {
      await repo.set('theme_mode', 'light');
      await repo.set('theme_mode', 'dark');
      final value = await repo.get('theme_mode');
      expect(value, 'dark');
    });

    test('delete removes a key', () async {
      await repo.set('temp_key', 'temp_value');
      await repo.delete('temp_key');
      final value = await repo.get('temp_key');
      expect(value, isNull);
    });

    test('delete on non-existent key does not throw', () async {
      await repo.delete('does_not_exist');
      // No exception means pass
    });

    test('getAll returns all settings', () async {
      await repo.set('key1', 'value1');
      await repo.set('key2', 'value2');
      await repo.set('key3', 'value3');
      final all = await repo.getAll();
      expect(all.length, 3);
      expect(all['key1'], 'value1');
      expect(all['key2'], 'value2');
      expect(all['key3'], 'value3');
    });

    test('getAll returns empty map when no settings', () async {
      final all = await repo.getAll();
      expect(all, isEmpty);
    });

    test('handles Unicode values', () async {
      await repo.set('nickname', '小明🎓');
      final value = await repo.get('nickname');
      expect(value, '小明🎓');
    });

    test('handles empty string value', () async {
      await repo.set('empty', '');
      final value = await repo.get('empty');
      expect(value, '');
    });

    test('handles long value', () async {
      final longValue = 'x' * 10000;
      await repo.set('long_key', longValue);
      final value = await repo.get('long_key');
      expect(value, longValue);
    });
  });
}
