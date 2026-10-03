import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales no sensibles (constitución VI: nada de credenciales).
class LocalStorage {
  LocalStorage(this._prefs);

  static Future<LocalStorage> create() async {
    return LocalStorage(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  /// Devuelve `null` si la clave no existe o el contenido no es un objeto JSON.
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}
