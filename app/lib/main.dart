import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';  // web
import 'package:web_socket_channel/io.dart';    // non-web

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final String apiBase = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  final String wsUrl   = const String.fromEnvironment('WS_URL',       defaultValue: 'ws://localhost:3000/ws');

  String health = 'pending...';
  List<dynamic> wsData = [];
  WebSocketChannel? _chan;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _connectWs();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _checkHealth());
  }

  Future<void> _checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/health'));
      setState(() => health = '${res.statusCode}: ${res.body}');
    } catch (e) {
      setState(() => health = 'error: $e');
    }
  }

  void _connectWs() {
    try {
      _chan = kIsWeb
          ? HtmlWebSocketChannel.connect(wsUrl)
          : IOWebSocketChannel.connect(wsUrl);

      _chan!.stream.listen((msg) {
        try {
          final decoded = jsonDecode(msg);
          setState(() => wsData = decoded is List ? decoded : [decoded]);
        } catch (_) {}
      }, onDone: _reconnectWs, onError: (_) => _reconnectWs());
    } catch (e) {
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
      home: Scaffold(
        appBar: AppBar(title: const Text('IoT App — MVP')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('API_BASE_URL: $apiBase'),
              Text('WS_URL: $wsUrl'),
              const SizedBox(height: 8),
              Text('Health → $health'),
              const Divider(),
              const Text('WS sample (last up to 5 rows):'),
              ...items,
              const Spacer(),
              ElevatedButton(
                onPressed: _checkHealth,
                child: const Text('Ping /health'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
