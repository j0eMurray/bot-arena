// ignore_for_file: avoid_web_libraries_in_flutter
// Este archivo solo se activa cuando dart.library.html está disponible (web).
//
// Reexporta los símbolos estrictamente necesarios desde dart:html para
// mantener el tipado sin usar 'dart:html' directamente en main.dart.
export 'dart:html' show WebSocket, window;
