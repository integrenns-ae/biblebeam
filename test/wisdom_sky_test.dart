import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bibelquiz/screens/wisdom_sky_screen.dart';
import 'package:bibelquiz/services/settings_service.dart';
import 'package:bibelquiz/services/stats_service.dart';

void main() {
  testWidgets('Sternbild der Weisheit: Vers, Sternanzahl und Rang', (tester) async {
    SettingsService.instance.locale.value = 'de';
    StatsService.instance.totalCorrect.value = 120; // -> Rang "Leuchtender Pfad" (>=100)

    await tester.pumpWidget(const MaterialApp(home: WisdomSkyScreen()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    expect(find.textContaining('Verständigen werden leuchten'), findsOneWidget); // Daniel 12,3
    expect(find.text('120'), findsOneWidget); // Anzahl leuchtender Sterne
    expect(find.text('Leuchtender Pfad'), findsOneWidget); // Rang/Sternbild

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
