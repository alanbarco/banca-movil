import 'dart:convert';

/// Versión máxima de esquema que esta build entiende para los parámetros JSON.
const supportedSchemaVersion = 1;

/// Decodifica un parámetro JSON versionado de Remote Config.
///
/// Devuelve `null` si no es un objeto JSON, si falta `schemaVersion` o si es
/// mayor que [supportedSchemaVersion].
Map<String, dynamic>? decodeVersionedJson(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return isSupportedSchema(decoded) ? decoded : null;
  } on FormatException {
    return null;
  }
}

bool isSupportedSchema(Map<String, dynamic> json) {
  final version = json['schemaVersion'];
  return version is int && version >= 1 && version <= supportedSchemaVersion;
}
