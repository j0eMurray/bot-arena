// app/lib/config/app_urls.dart
/// Provee las URLs base de la API para HTTP y WS.
/// Lee de --dart-define (API_HTTP, API_WS) y si no están, usa defaults locales.
/// Incluye además atajos de conveniencia (health, wsOfficial, wsTest)
/// y helpers compatibles con tu código previo: http(path), ws(path).
class AppUrls {
  /// p.ej: http://192.168.1.146:5274
  static String get httpBase {
    const fromEnv = String.fromEnvironment('API_HTTP');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://127.0.0.1:3000';
  }

  /// p.ej: ws://192.168.1.146:5274
  static String get wsBase {
    const fromEnv = String.fromEnvironment('API_WS');
    if (fromEnv.isNotEmpty) return fromEnv;

    // Derivar desde httpBase si no viene por dart-define
    final u = Uri.parse(httpBase);
    final scheme = (u.scheme == 'https') ? 'wss' : 'ws';
    final port = u.hasPort ? ':${u.port}' : '';
    return '$scheme://${u.host}$port';
  }

  // ========= Helpers privados para compatibilidad con tu código previo =========
  static String _httpBase() => httpBase;
  static String _wsBase() => wsBase;

  static String _norm(String path) {
    if (path.isEmpty) return '';
    return path.startsWith('/') ? path : '/$path';
  }

  // ==================== Atajos de conveniencia ====================
  static String get health => '${_httpBase()}/health';
  static String get wsOfficial => '${_wsBase()}/ws';
  static String get wsTest => '${_wsBase()}/ws-test';

  // ==================== Helpers estilo "http('/ruta')" ====================
  static String http(String path) => '${_httpBase()}${_norm(path)}';
  static String ws(String path) => '${_wsBase()}${_norm(path)}';
}
