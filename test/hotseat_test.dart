import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bibelquiz/models/question.dart';
import 'package:bibelquiz/screens/hotseat_game_screen.dart';

Question q(String id, String correct) => Question(
      id: id,
      categories: const ['general'],
      difficulty: 2,
      question: 'Frage $id?',
      options: [correct, 'Falsch A', 'Falsch B', 'Falsch C'],
      answer: correct,
    );

void main() {
  testWidgets('Hotseat: Antworten, schwebender Weiter-Pfeil, Spielerwechsel',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HotseatGameScreen(
        questions1: [q('a1', 'Richtig1'), q('a2', 'Richtig2')],
        questions2: [q('b1', 'RichtigX'), q('b2', 'RichtigY')],
        name1: 'Papa',
        name2: 'Kind',
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Erste Frage (Spieler 1) sichtbar, Score-Sterne vorhanden.
    expect(find.text('Frage a1?'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsWidgets);
    // In der Antwortphase gibt es noch KEINEN Weiter-Pfeil.
    expect(find.byKey(const Key('hotseat-next')), findsNothing);

    // Richtige Antwort tippen -> Reveal + Weiter-Pfeil erscheint (schwebend).
    await tester.tap(find.text('Richtig1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('hotseat-next')), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsWidgets); // erster Stern glüht

    // Weiter -> nächster Zug ist Spieler 2 mit dessen Frage.
    await tester.tap(find.byKey(const Key('hotseat-next')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Frage b1?'), findsOneWidget);
    expect(find.byKey(const Key('hotseat-next')), findsNothing);
    expect(tester.takeException(), isNull);

    // Screen sauber abhängen -> Controller/Ticker/Timer werden entsorgt.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Hotseat: Desktop-Layout (breit) rendert ohne Fehler',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: HotseatGameScreen(
        questions1: [q('a1', 'Richtig1')],
        questions2: [q('b1', 'RichtigX')],
        name1: 'Papa',
        name2: 'Kind',
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Papa'), findsOneWidget); // linkes Spieler-Panel
    expect(find.text('Kind'), findsOneWidget); // rechtes Spieler-Panel
    expect(find.text('Frage a1?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
