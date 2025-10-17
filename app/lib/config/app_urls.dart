// lib/config/app_urls.dart
//
// Construcción de URLs de tu API a partir de Env.
// Evita concatenaciones repetidas y mantiene consistencia.

import 'env.dart';

class AppUrls {
  /// GET /health
  static String get health => '${_httpBase()}/health';

  /// WS /ws (canal “oficial”)
  static String get wsOfficial => '${_wsBase()}/ws';

  /// WS /ws-test (canal de prueba)
  static String get wsTest => '${_wsBase()}/ws-test';

  /// Si necesitas construir rutas REST: AppUrls.http('/users/me')
  static String http(String path) => '${_httpBase()}${_norm(path)}';

  /// Si necesitas construir rutas WS dinámicas: AppUrls.ws('/room/123')
  static String ws(String path) => '${_wsBase()}${_norm(path)}';

  // Internos
  static String _httpBase() => Env.apiHttp.replaceAll(RegExp(r'/$'), '');
  static String _wsBase()   => Env.apiWs.replaceAll(RegExp(r'/$'), '');

  static String _norm(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }
}
