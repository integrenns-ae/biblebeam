// Smoke-Test: App baut ohne Fehler.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bibelquiz/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BibelquizApp());
    await tester.pump(); // eine Frame (Hintergrund-Animationen laufen dauerhaft)
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
