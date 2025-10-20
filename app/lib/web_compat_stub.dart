// Stub mínimo para plataformas no-web o para el analizador cuando no hay dart:html.

class WebSocket {
  // Solo para satisfacer tipos; no lo usamos fuera de web.
}

class _Window {
  // Placeholder sin API; no se invoca en no-web.
}

final _Window window = _Window();
