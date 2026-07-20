import 'package:flutter/foundation.dart';

class AppConfig {
  static const bool isProduction = true;

  static const String _androidEmulatorUrl = 'http://10.0.2.2:5177/api/';
  static const String _localWebUrl = 'https://localhost:7048/api/';
  static const String _serverUrl = 'https://auras-api.aries-engg.com/api/';

  static String get baseUrl {
    if (isProduction) return _serverUrl;

    if (kIsWeb) return _localWebUrl;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorUrl;
    }

    return _localWebUrl;
  }
}
