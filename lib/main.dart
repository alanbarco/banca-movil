import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

// Bootstrap mínimo de la Fase 1 (Setup). Se reemplaza en la Fase 2 (T041)
// por el arranque completo: Crashlytics, Remote Config, DI y router.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(BiApp(projectId: Firebase.app().options.projectId));
}

class BiApp extends StatelessWidget {
  const BiApp({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BI App',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'BI App · Firebase conectado ($projectId)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
