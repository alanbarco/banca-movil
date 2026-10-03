import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Opciones de Firebase leídas en tiempo de compilación desde `.env`
/// (`flutter run --dart-define-from-file=.env`). Ver `.env.example`.
///
/// Las claves no se versionan; este archivo reemplaza al generado por
/// FlutterFire CLI. No volver a ejecutar `flutterfire configure` sin
/// restaurar este formato.
class DefaultFirebaseOptions {
  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'BI App solo tiene Firebase configurado para Android.',
      );
    }
    return android;
  }

  static FirebaseOptions get android {
    if (_androidApiKey.isEmpty || _androidAppId.isEmpty || _projectId.isEmpty) {
      throw StateError(
        'Faltan las variables de Firebase. Ejecuta con '
        '--dart-define-from-file=.env (ver .env.example).',
      );
    }
    return const FirebaseOptions(
      apiKey: _androidApiKey,
      appId: _androidAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket,
    );
  }
}
