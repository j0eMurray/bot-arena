// app/lib/telemetry_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // FontFeature

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/app_urls.dart';

class TelemetryPage extends StatefulWidget {
  const TelemetryPage({super.key});

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage> {
  static const int _defaultLimit = 50;
  static const Duration _pollEvery = Duration(seconds: 2);

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchOnce();
    _timer = Timer.periodic(_pollEvery, (_) => _fetchOnce());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOnce() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = '${AppUrls.httpBase}/telemetry?limit=$_defaultLimit';
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase ?? ''}');
      }

      final decoded = json.decode(res.body) as Map<String, dynamic>;
      final ok = decoded['ok'] == true;
      if (!ok) {
        throw Exception('Respuesta no OK');
      }

      final List<dynamic> data =
          decoded['data'] as List<dynamic>? ?? <dynamic>[];
      final list = data
          .whereType<Map<String, dynamic>>()
          .map<Map<String, dynamic>>((e) => {
                'id': e['id'],
                'ts': e['ts'],
                'device_id': e['device_id'],
                'topic': e['topic'],
                'payload': e['payload'],
              })
          .toList(growable: false);

      setState(() {
        _rows = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _manualRefresh() async {
    await _fetchOnce();
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final String id = (row['id'] ?? '').toString();
    final String ts = (row['ts'] ?? '').toString();
    final String deviceId = (row['device_id'] ?? '').toString();
    final String topic = row['topic'] == null ? '' : row['topic'].toString();

    String payloadPretty = '';
    final payload = row['payload'];
    if (payload != null) {
      try {
        payloadPretty = const JsonEncoder.withIndent('  ').convert(payload);
      } catch (_) {
        payloadPretty = payload.toString();
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('ID: $id',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (deviceId.isNotEmpty) Text('Device: $deviceId'),
                  if (ts.isNotEmpty)
                    Text(
                      ts,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              if (topic.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Topic: $topic',
                    style: const TextStyle(color: Colors.black87)),
              ],
              if (payloadPretty.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      payloadPretty,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_rows.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sin datos de telemetría (todavía).',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _manualRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _rows.length,
        itemBuilder: (context, index) => _buildRow(_rows[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetría'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _manualRefresh,
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
