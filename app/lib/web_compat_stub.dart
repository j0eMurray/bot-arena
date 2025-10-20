// Stub para plataformas no-web y para el analizador en CI.
// Debe compilar sin dependencias web.

import 'dart:async';

class WebSocket {
  WebSocket(String url);

  Stream<void> get onOpen => const Stream.empty();
  Stream<void> get onClose => const Stream.empty();
  Stream<void> get onError => const Stream.empty();
  Stream<void> get onMessage => const Stream.empty();

  void sendString(String data) {}
  void close([int? code, String? reason]) {}
}

// Stub de window para evitar referencias accidentales en no-web.
class _WindowStub {}
final window = _WindowStub();
