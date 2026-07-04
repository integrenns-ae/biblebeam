import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bibelquiz/models/question.dart';
import 'package:bibelquiz/screens/quiz_screen.dart';

void main() {
  testWidgets('Solo-Quiz zeigt die Bibelstelle bei der Auflösung', (tester) async {
    // Alle Fragen haben dieselbe richtige Antwort "RICHTIG" und eine Referenz,
    // damit der Tap unabhängig von der zufällig gezogenen Frage funktioniert.
    final pool = List.generate(
      10,
      (i) => Question(
        id: 'q$i',
        categories: const ['general'],
        difficulty: 3,
        question: 'Frage $i?',
        options: const ['RICHTIG', 'Falsch A', 'Falsch B', 'Falsch C'],
        answer: 'RICHTIG',
        reference: 'Haggai 1,9',
      ),
    );

    await tester.pumpWidget(MaterialApp(home: QuizScreen(pool: pool, title: 'Test')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Vor der Antwort: keine Bibelstelle sichtbar.
    expect(find.text('Haggai 1,9'), findsNothing);

    // Richtige Antwort tippen -> Auflösung -> Bibelstelle erscheint.
    await tester.tap(find.text('RICHTIG'));
    await tester.pump(const Duration(milliseconds: 300)); // < 1400ms Auto-Weiter
    expect(find.text('Haggai 1,9'), findsOneWidget);

    // Auto-Weiter abwarten, damit der 1400ms-Timer feuert (kein Pending-Timer).
    await tester.pump(const Duration(milliseconds: 1300));
    // Sauber abhängen (Ticker entsorgen).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
