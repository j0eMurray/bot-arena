// ignore_for_file: deprecated_member_use
// Implementación real para WEB usando dart:html.
// El analizador marca dart:html como "deprecated" fuera de plugins,
// pero en web puro está OK (y no rompe el CI porque es "info").

import 'dart:async';
import 'dart:html' as html;

class WebSocket {
  final html.WebSocket _ws;

  WebSocket(String url) : _ws = html.WebSocket(url);

  // Streams equivalentes a dart:html
  Stream<html.Event> get onOpen => _ws.onOpen;
  Stream<html.Event> get onClose => _ws.onClose;
  Stream<html.Event> get onError => _ws.onError;
  Stream<html.MessageEvent> get onMessage => _ws.onMessage;

  void sendString(String data) => _ws.sendString(data);

  void close([int? code, String? reason]) => _ws.close(code, reason);
}

// Exponemos window si lo necesitas en algún punto.
final window = html.window;
