// lib/config/env.dart
//
// Mecanismo unificado para leer variables de entorno en Flutter.
// Prioridad:
//   1) --dart-define=API_HTTP=... / --dart-define=API_WS=... (build-time)
//   2) Platform.environment['API_HTTP'|'API_WS'] (runtime, no disponible en Web)
//   3) Fallback por defecto (localhost)
// Esto permite que tu app funcione igual en Web (con web-server),
// escritorio/móvil (leyendo env), y builds de release (incrustado en compile time).

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  // Valores por defecto seguros para desarrollo local
  static const _defaultHttp = 'http://localhost:3000';
  static const _defaultWs   = 'ws://localhost:3000';

  /// HTTP base (e.g., http://192.168.1.146:5274)
  static final String apiHttp = _getVar(
    key: 'API_HTTP',
    fallback: _defaultHttp,
  );

  /// WS base (e.g., ws://192.168.1.146:5274)
  static final String apiWs = _getVar(
    key: 'API_WS',
    fallback: _defaultWs,
  );

  /// Lee una variable con la estrategia descrita en el encabezado.
  static String _getVar({required String key, required String fallback}) {
    // 1) En cualquier plataforma, intentamos primero --dart-define
    const fromDefine = String.fromEnvironment;
    final defineValue = fromDefine(key);
    if (defineValue.isNotEmpty) return defineValue;

    // 2) En plataformas NO web, podemos intentar Platform.environment
    if (!kIsWeb) {
      final envValue = Platform.environment[key];
      if (envValue != null && envValue.isNotEmpty) return envValue;
    }

    // 3) Fallback (desarrollo local)
    return fallback;
  }
}
