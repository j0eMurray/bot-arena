// app/lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/app_urls.dart';
import 'temp_tests_page.dart';
import 'telemetry_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Bot Arena',
      theme: theme,
      home: const MyHomePage(title: 'Bot Arena'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum WsState { idle, connecting, open, closed, error }

class _MyHomePageState extends State<MyHomePage> {
  String? _health;
  String? _healthError;

  WsState _wsState = WsState.idle;
  html.WebSocket? _ws;
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkHealth());
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _closeWs();
    super.dispose();
  }

  String _apiBase() => AppUrls.httpBase;

  Uri _wsUri(String path) {
    // Si ya te dan la base WS, úsala respetando el path
    final base = AppUrls.wsBase; // p.ej. ws://192.168.1.146:5274
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final b = Uri.parse(base);
    return Uri(
      scheme: b.scheme,
      host: b.host,
      port: b.hasPort ? b.port : null,
      path: cleanPath,
    );
  }

  Future<void> _checkHealth() async {
    setState(() {
      _healthError = null;
    });

    try {
      final uri = Uri.parse('${_apiBase()}/health');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final decoded = json.decode(res.body) as Map<String, dynamic>;
      setState(() {
        _health = decoded['ok'] == true ? 'OK' : 'DOWN';
      });
    } catch (e) {
      setState(() {
        _health = null;
        _healthError = e.toString();
      });
    }
  }

  void _openWs() {
    if (_wsState == WsState.open || _wsState == WsState.connecting) return;

    setState(() {
      _wsState = WsState.connecting;
    });

    final wsUrl = _wsUri('/ws').toString();

    final ws = html.WebSocket(wsUrl);
    ws.onOpen.listen((_) {
      setState(() => _wsState = WsState.open);
    });
    ws.onClose.listen((_) {
      setState(() => _wsState = WsState.closed);
    });
    ws.onError.listen((_) {
      setState(() => _wsState = WsState.error);
    });
    ws.onMessage.listen((event) {
      // print('WS message: ${event.data}');
    });

    _ws = ws;
  }

  void _closeWs() {
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    setState(() => _wsState = WsState.closed);
  }

  @override
  Widget build(BuildContext context) {
    final healthy = _health == 'OK';
    final wsOpen = _wsState == WsState.open;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Comprobar /health',
            onPressed: _checkHealth,
            icon: const Icon(Icons.health_and_safety),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Bot Arena',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Inicio'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Telemetría'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TelemetryPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Temp tests'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TempTestsPage(
                        apiHttp: AppUrls.httpBase,
                        apiWs: AppUrls.wsBase,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final side = Expanded(
            child: _StatusCard(
              healthy: healthy,
              healthText: _health,
              healthError: _healthError,
              wsState: _wsState,
              onCheckHealth: _checkHealth,
              onOpenWs: _openWs,
              onCloseWs: _closeWs,
              httpBase: AppUrls.httpBase,
            ),
          );

          final actions = Expanded(
            child: _ActionsCard(
              onOpenWs: _openWs,
              onCloseWs: _closeWs,
              wsOpen: wsOpen,
              httpBase: AppUrls.httpBase,
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [side, actions],
            );
          } else {
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                side,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.healthy,
    required this.healthText,
    required this.healthError,
    required this.wsState,
    required this.onCheckHealth,
    required this.onOpenWs,
    required this.onCloseWs,
    required this.httpBase,
  });

  final bool healthy;
  final String? healthText;
  final String? healthError;
  final WsState wsState;
  final VoidCallback onCheckHealth;
  final VoidCallback onOpenWs;
  final VoidCallback onCloseWs;
  final String httpBase;

  @override
  Widget build(BuildContext context) {
    final color = healthy ? Colors.green : Colors.redAccent;

    String wsLabel;
    switch (wsState) {
      case WsState.idle:
        wsLabel = 'idle';
        break;
      case WsState.connecting:
        wsLabel = 'connecting';
        break;
      case WsState.open:
        wsLabel = 'open';
        break;
      case WsState.closed:
        wsLabel = 'closed';
        break;
      case WsState.error:
        wsLabel = 'error';
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado API /health',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 12, color: color),
                  const SizedBox(width: 8),
                  Text(healthText ?? '—'),
                ],
              ),
              if (healthError != null) ...[
                const SizedBox(height: 8),
                Text(
                  healthError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const Divider(height: 24),
              Text('Estado WebSocket (/ws)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(wsLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenWs,
                    icon: const Icon(Icons.wifi),
                    label: const Text('Abrir WS'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCloseWs,
                    icon: const Icon(Icons.wifi_off),
                    label: const Text('Cerrar WS'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCheckHealth,
                    icon: const Icon(Icons.health_and_safety),
                    label: const Text('Revisar /health'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('HTTP base: $httpBase',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.onOpenWs,
    required this.onCloseWs,
    required this.wsOpen,
    required this.httpBase,
  });

  final VoidCallback onOpenWs;
  final VoidCallback onCloseWs;
  final bool wsOpen;
  final String httpBase;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acciones / Info',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('HTTP base: $httpBase'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: wsOpen ? onCloseWs : onOpenWs,
                    child: Text(wsOpen ? 'Cerrar WS' : 'Abrir WS'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TempTestsPage(
                            apiHttp: AppUrls.httpBase,
                            apiWs: AppUrls.wsBase,
                          ),
                        ),
                      );
                    },
                    child: const Text('Temp tests'),
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
