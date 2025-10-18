import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';  // Web
import 'package:web_socket_channel/io.dart';    // Desktop/Mobile

import 'temp_tests_page.dart';

/// ============================================================================
/// ENV para Flutter Web (y también válido en native):
/// - Solo usamos --dart-define (compile-time) vía String.fromEnvironment.
/// - No usamos Platform.environment (rompe en Web).
/// - Compatibilidad con nombres antiguos: API_BASE_URL (HTTP) y WS_URL (WS).
/// ============================================================================
class Env {
  // Define nuevos con fallback a define antiguos. Si ninguno viene, queda cadena vacía.
  static const String _apiHttpDefine = String.fromEnvironment(
    'API_HTTP',
    defaultValue: String.fromEnvironment('API_BASE_URL', defaultValue: ''),
  );
  static const String _apiWsDefine = String.fromEnvironment(
    'API_WS',
    defaultValue: String.fromEnvironment('WS_URL', defaultValue: ''),
  );

  static const String _defaultHttp = 'http://localhost:3000';
  static const String _defaultWs   = 'ws://localhost:3000';

  /// HTTP base (e.g., http://192.168.1.146:5274)
  static String get apiHttp => _apiHttpDefine.isNotEmpty ? _apiHttpDefine : _defaultHttp;

  /// WS base (e.g., ws://192.168.1.146:5274)
  static String get apiWs   => _apiWsDefine.isNotEmpty ? _apiWsDefine : _defaultWs;
}

/// URLs centralizadas para evitar hardcodes y concatenaciones repetidas.
class AppUrls {
  static String get health => '${_httpBase()}/health';
  static String get ws     => '${_wsBase()}/ws';
  static String get wsTest => '${_wsBase()}/ws-test';

  static String http(String path) => '${_httpBase()}${_norm(path)}';
  static String wsCustom(String path) => '${_wsBase()}${_norm(path)}';

  static String _httpBase() => Env.apiHttp.replaceAll(RegExp(r'/$'), '');
  static String _wsBase()   => Env.apiWs.replaceAll(RegExp(r'/$'), '');
  static String _norm(String p) => p.startsWith('/') ? p : '/$p';
}

/// ============================================================================
/// APP
/// ============================================================================
void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String health = 'pending...';
  List<dynamic> wsData = [];
  WebSocketChannel? _chan;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _connectWs();
    // Ping periódico para diagnosticar estabilidad de la API
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _checkHealth());
  }

  Future<void> _checkHealth() async {
    try {
      final res = await http.get(Uri.parse(AppUrls.health));
      setState(() => health = '${res.statusCode}: ${res.body}');
    } catch (e) {
      setState(() => health = 'error: $e');
    }
  }

  void _connectWs() {
    final wsUrl = AppUrls.ws; // canal oficial /ws
    try {
      _chan = kIsWeb
          ? HtmlWebSocketChannel.connect(wsUrl)
          : IOWebSocketChannel.connect(wsUrl);

      _chan!.stream.listen((msg) {
        try {
          final decoded = jsonDecode(msg);
          setState(() => wsData = decoded is List ? decoded : [decoded]);
        } catch (_) {
          // Mensaje no JSON; ignoramos silenciosamente
        }
      }, onDone: _reconnectWs, onError: (_) => _reconnectWs());
    } catch (_) {
      _reconnectWs();
    }
  }

  void _reconnectWs() {
    Future.delayed(const Duration(seconds: 2), _connectWs);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chan?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = wsData.take(5).map((e) => Text(e.toString())).toList();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'bot-arena',
      home: Scaffold(
        appBar: AppBar(title: const Text('bot-arena — MVP')),
        drawer: Drawer(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Text('Menú', style: TextStyle(fontSize: 20)),
              ),
              // Sección activa actual: Temp-tests
              ListTile(
                leading: const Icon(Icons.science),
                title: const Text('Temp-tests'),
                subtitle: const Text('Página temporal de pruebas'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TempTestsPage(
                      apiHttp: Env.apiHttp,
                      apiWs: Env.apiWs,
                    ),
                  ));
                },
              ),
              const Divider(),
              // Placeholders (a implementar luego)
              const ListTile(
                leading: Icon(Icons.login),
                title: Text('Login'),
                subtitle: Text('Próximamente'),
                enabled: false,
              ),
              const ListTile(
                leading: Icon(Icons.memory),
                title: Text('Devices'),
                subtitle: Text('Listado / registro (próximamente)'),
                enabled: false,
              ),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('API_HTTP: ${Env.apiHttp}'),
              Text('API_WS  : ${Env.apiWs}'),
              const SizedBox(height: 8),
              Text('Health → $health'),
              const Divider(),
              const Text('WS sample (last up to 5 rows):'),
              ...items,
              const Spacer(),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _checkHealth,
                    child: const Text('Ping /health'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Cambia temporalmente al canal /ws-test por 10s
                      _chan?.sink.close();
                      wsData = [];
                      setState(() {});
                      final testUrl = AppUrls.wsTest;
                      _chan = kIsWeb
                          ? HtmlWebSocketChannel.connect(testUrl)
                          : IOWebSocketChannel.connect(testUrl);
                      _chan!.stream.listen((msg) {
                        setState(() => wsData = [msg]);
                      });
                      Future.delayed(const Duration(seconds: 10), () {
                        _chan?.sink.close();
                        _connectWs(); // volvemos al canal oficial
                      });
                    },
                    child: const Text('Probar /ws-test (10s)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
