import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';  // Web
import 'package:web_socket_channel/io.dart';    // Desktop/Mobile

/// Temp-tests: pantalla temporal de pruebas.
/// Recibe [apiHttp] y [apiWs] desde main.dart.
class TempTestsPage extends StatefulWidget {
  final String apiHttp;
  final String apiWs;

  const TempTestsPage({
    super.key,
    required this.apiHttp,
    required this.apiWs,
  });

  @override
  State<TempTestsPage> createState() => _TempTestsPageState();
}

class _TempTestsPageState extends State<TempTestsPage> {
  String health = 'pending...';
  List<dynamic> wsData = [];
  List<Map<String, dynamic>> recent = [];
  WebSocketChannel? _chan;
  Timer? _timer;

  String get _healthUrl => '${widget.apiHttp.replaceAll(RegExp(r'/$'), '')}/health';
  String get _wsUrl     => '${widget.apiWs.replaceAll(RegExp(r'/$'), '')}/ws';
  String _telemetryUrl({int limit = 20, String? deviceId}) {
    final base = '${widget.apiHttp.replaceAll(RegExp(r'/$'), '')}/telemetry';
    final q = <String>[
      'limit=$limit',
      if (deviceId != null && deviceId.isNotEmpty) 'device_id=$deviceId',
    ].join('&');
    return '$base?$q';
  }

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _connectWs();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _checkHealth());
  }

  Future<void> _checkHealth() async {
    try {
      final res = await http.get(Uri.parse(_healthUrl));
      setState(() => health = '${res.statusCode}: ${res.body}');
    } catch (e) {
      setState(() => health = 'error: $e');
    }
  }

  Future<void> _fetchRecent() async {
    try {
      final url = _telemetryUrl(limit: 20);
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['ok'] == true && body['data'] is List) {
          final List data = body['data'];
          setState(() {
            recent = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {}
  }

  void _connectWs() {
    try {
      _chan = kIsWeb
          ? HtmlWebSocketChannel.connect(_wsUrl)
          : IOWebSocketChannel.connect(_wsUrl);

      _chan!.stream.listen((msg) {
        try {
          final decoded = jsonDecode(msg);
          setState(() => wsData = decoded is List ? decoded : [decoded]);
        } catch (_) {}
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
    final wsItems = wsData.take(5).map((e) => Text(e.toString())).toList();
    final recentItems = recent.map((row) {
      final ts = row['ts'] ?? '';
      final dev = row['device_id'] ?? '';
      final payload = jsonEncode(row['payload']);
      return Text('[$ts] $dev → $payload');
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Temp-tests')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('API_HTTP: ${widget.apiHttp}'),
            Text('API_WS  : ${widget.apiWs}'),
            const SizedBox(height: 8),
            Text('Health → $health'),
            const Divider(),
            const Text('WS sample (last up to 5 rows):'),
            ...wsItems,
            const SizedBox(height: 16),
            const Divider(),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _checkHealth,
                  child: const Text('Ping /health'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _fetchRecent,
                  child: const Text('Fetch telemetry (20)'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    // Cambia a /ws-test por 10s
                    _chan?.sink.close();
                    setState(() => wsData = []);
                    final url = '${widget.apiWs.replaceAll(RegExp(r'/$'), '')}/ws-test';
                    _chan = kIsWeb
                        ? HtmlWebSocketChannel.connect(url)
                        : IOWebSocketChannel.connect(url);
                    _chan!.stream.listen((msg) {
                      setState(() => wsData = [msg]);
                    });
                    Future.delayed(const Duration(seconds: 10), () {
                      _chan?.sink.close();
                      _connectWs();
                    });
                  },
                  child: const Text('Probar /ws-test (10s)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Recent telemetry:'),
            ...recentItems,
          ],
        ),
      ),
    );
  }
}
