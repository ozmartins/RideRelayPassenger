import 'package:shared_preferences/shared_preferences.dart';

import 'package:passenger/services/key_value_store.dart';

/// Implementação real sobre `shared_preferences` (decisão D3).
class PrefsKeyValueStore implements KeyValueStore {
  const PrefsKeyValueStore();

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

/// Como [PrefsKeyValueStore], mas relê o disco a cada leitura: o serviço em
/// segundo plano roda em outro isolate, que não compartilha o cache de
/// `shared_preferences` com a interface (feature 026, D7 de `research.md`).
class FreshPrefsKeyValueStore implements KeyValueStore {
  const FreshPrefsKeyValueStore();

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
