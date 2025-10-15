import 'package:flutter/material.dart';
import 'telemetry_page.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: TelemetryPage(),
  ));
}

/*import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

Uri _wsUri() {
  final isHttps = windowLocationProtocolIsHttps();
  final host = windowLocationHost();
  final scheme = isHttps ? 'wss' : 'ws';
  // Ruta relativa unificada detrás de Caddy
  return Uri.parse('$scheme://$host/ws');
}

Uri _healthUri() {
  final isHttps = windowLocationProtocolIsHttps();
  final host = windowLocationHost();
  final scheme = isHttps ? 'https' : 'http';
  return Uri.parse('$scheme://$host/api/health');
}

// Helpers para web sin importar dart:html en móviles.
bool windowLocationProtocolIsHttps() {
  // Cuando corre en web, `const bool.fromEnvironment('dart.library.html')` no sirve.
// Hacemos un hack simple leyendo desde Uri.base:
  return Uri.base.scheme == 'https';
}

String windowLocationHost() {
  // Uri.base incluye host:puerto de la página actual
  return Uri.base.authority; // e.g. 192.168.1.146:5274
}

class TelemetryPage extends StatefulWidget {
  const TelemetryPage({super.key});

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage> {
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  bool _wsOpen = false;
  DateTime? _lastMsgAt;
  Object? _wsLastError;

  bool _healthOk = false;
  String _healthMsg = '';
  Timer? _healthTimer;

  // Últimos datos recibidos (lista dinámica)
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _connectWs();
    _startHealthPolling();
  }

  void _connectWs() {
    // Cierra anterior si quedara viva
    _channel?.sink.close();
    _wsSub?.cancel();

    final uri = _wsUri();
    _channel = WebSocketChannel.connect(uri);
    _wsOpen = true;
    _wsLastError = null;
    setState(() {});

    _wsSub = _channel!.stream.listen(
      (data) {
        _lastMsgAt = DateTime.now();
        try {
          final decoded = jsonDecode(data);
          // Esperamos una lista de objetos; si viene un mapa, lo envolvemos
          final list = decoded is List ? decoded : [decoded];
          setState(() {
            _items = list;
          });
        } catch (e) {
          _wsLastError = e;
          setState(() {});
        }
      },
      onError: (e) {
        _wsOpen = false;
        _wsLastError = e;
        setState(() {});
      },
      onDone: () {
        _wsOpen = false;
        setState(() {});
        // Reintento simple
        Future.delayed(const Duration(seconds: 2), _connectWs);
      },
      cancelOnError: false,
    );
  }

  void _startHealthPolling() {
    Future<void> ping() async {
      try {
        final res = await http.get(_healthUri()).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          _healthOk = (body is Map && body['ok'] == true);
          _healthMsg = _healthOk ? 'ok' : 'respuesta inesperada';
        } else {
          _healthOk = false;
          _healthMsg = 'HTTP ${res.statusCode}';
        }
      } catch (e) {
        _healthOk = false;
        _healthMsg = '$e';
      }
      if (mounted) setState(() {});
    }

    // Primer ping inmediato y luego cada 5s
    ping();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) => ping());
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsStatus = _wsOpen ? 'conectado' : 'desconectado';
    final lastMsg = _lastMsgAt != null
        ? timeAgo(_lastMsgAt!)
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor WS / Health'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de estado
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text('API health: ${_healthOk ? 'OK' : 'DOWN'} (${_healthMsg})'),
                  backgroundColor: _healthOk ? Colors.green.shade200 : Colors.red.shade200,
                ),
                Chip(
                  label: Text('WS: $wsStatus'),
                  backgroundColor: _wsOpen ? Colors.green.shade200 : Colors.orange.shade200,
                ),
                Chip(
                  label: Text('Último msg: $lastMsg'),
                ),
                if (_wsLastError != null)
                  Chip(
                    label: Text('WS error: ${_wsLastError}'),
                    backgroundColor: Colors.red.shade200,
                  ),
                TextButton(
                  onPressed: _connectWs,
                  child: const Text('Reconectar WS'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de items
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Sin datos aún…'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = _items[index];
                      if (row is Map) {
                        final deviceId = '${row['device_id'] ?? row['deviceId'] ?? '—'}';
                        final ts = '${row['ts'] ?? row['timestamp'] ?? '—'}';
                        final payload = row['payload'];
                        final payloadStr = _shortJson(payload);
                        return ListTile(
                          title: Text('$deviceId  •  $ts'),
                          subtitle: Text(payloadStr, maxLines: 2, overflow: TextOverflow.ellipsis),
                        );
                      } else {
                        return ListTile(
                          title: Text(row.toString()),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _shortJson(dynamic v) {
    try {
      final s = const JsonEncoder.withIndent('  ').convert(v);
      return s.length <= 400 ? s : s.substring(0, 400) + ' …';
    } catch (_) {
      return v?.toString() ?? '—';
    }
  }

  static String timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}*/