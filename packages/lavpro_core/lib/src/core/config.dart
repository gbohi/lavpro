import 'package:flutter/foundation.dart';

/// Configuration de l'application (surchargée via --dart-define=API_URL=...).
class AppConfig {
  static const _fromEnv = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api/v1';
    return 'http://localhost:8000/api/v1';
  }

  static const qrPrefix = 'LAVPRO:';
}
