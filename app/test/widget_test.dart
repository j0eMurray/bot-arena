import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import relativo para evitar depender del "name" del package en pubspec.yaml
import '../lib/main.dart';

void main() {
  testWidgets('App builds and shows MaterialApp', (tester) async {
    await tester.pumpWidget(const App());
    // Verificamos que haya al menos un MaterialApp en el árbol
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
