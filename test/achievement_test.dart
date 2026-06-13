import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bibelquiz/models/quiz_outcome.dart';
import 'package:bibelquiz/screens/achievements_screen.dart';
import 'package:bibelquiz/services/achievement_service.dart';
import 'package:bibelquiz/services/settings_service.dart';
import 'package:bibelquiz/services/stats_service.dart';

QuizOutcome quiz({
  required int correct,
  int total = 10,
  int diff = 2,
  String cat = 'gospels',
  DateTime? at,
  int elapsedMs = 8000,
}) {
  final answers = <AnsweredQuestion>[
    for (var i = 0; i < total; i++)
      AnsweredQuestion(
        questionId: 'q$i',
        difficulty: diff,
        categories: [cat],
        correct: i < correct,
        elapsedMs: elapsedMs,
      ),
  ];
  return QuizOutcome(
    answers: answers,
    score: 100,
    bestStreak: correct,
    finishedAt: at ?? DateTime(2026, 6, 13, 12),
  );
}

/// Singleton-Zustand zwischen Tests zurücksetzen.
void reset(AchievementService s) {
  s.hardCorrect = 0;
  s.comebackWins = 0;
  s.perfectQuizzes = 0;
  s.runningStreak = 0;
  s.reachedIron = false;
  s.fastCorrect = false;
  s.earlyPerfect = false;
  s.midnight = false;
  s.holyNight = false;
  s.narrowPath = false;
  s.areaCorrect = {};
  s.playStreak = 0;
  s.playStreakLongest = 0;
  s.lastPlayDay = null;
  s.q80Day = null;
  s.q80Correct = 0;
  s.q80Questions = 0;
  s.q80Streak = 0;
  s.q80LastQualDay = null;
  s.perfectDayStreak = 0;
  s.perfectDayLast = null;
  s.unlocked = {};
  StatsService.instance.gamesPlayed.value = 0;
  StatsService.instance.totalCorrect.value = 0;
  StatsService.instance.totalQuestions.value = 0;
}

/// Spiegelt den Produktiv-Ablauf: erst Statistik, dann Achievements.
Future<List<Achievement>> play(AchievementService s, QuizOutcome o) async {
  await StatsService.instance.recordGame(
    correct: o.correct, questions: o.total, score: o.score, streak: o.bestStreak);
  return s.recordQuiz(o);
}

void main() {
  late AchievementService s;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await StatsService.instance.init();
    s = AchievementService.instance;
    await s.init();
    reset(s);
  });

  test('Block 1: mengenbasierte Stufen schalten frei', () async {
    for (var i = 0; i < 10; i++) {
      await play(s, quiz(correct: 6, at: DateTime(2026, 1, 1, 12)));
    }
    expect(s.isUnlocked('reise_01'), isTrue);
    expect(s.isUnlocked('reise_02'), isTrue); // 10 Spiele
    expect(s.isUnlocked('reise_03'), isFalse); // braucht 50
  });

  test('Rückwirkend: bestehende Spielanzahl schaltet sofort frei', () async {
    StatsService.instance.gamesPlayed.value = 120;
    SharedPreferences.setMockInitialValues({});
    await s.init(); // wertet beim Start aus
    expect(s.isUnlocked('reise_04'), isTrue); // 100
    expect(s.isUnlocked('reise_05'), isFalse); // 300 + 30 schwere
  });

  test('Block 2: 3 aufeinanderfolgende Tage -> Dranbleiber', () async {
    await play(s, quiz(correct: 6, at: DateTime(2026, 3, 1, 10)));
    expect(s.isUnlocked('serie_01'), isFalse);
    await play(s, quiz(correct: 6, at: DateTime(2026, 3, 2, 10)));
    await play(s, quiz(correct: 6, at: DateTime(2026, 3, 3, 10)));
    expect(s.playStreakLongest, 3);
    expect(s.isUnlocked('serie_01'), isTrue);
  });

  test('Block 2: ausgelassener Tag setzt laufende Serie zurück', () async {
    await play(s, quiz(correct: 6, at: DateTime(2026, 3, 1, 10)));
    await play(s, quiz(correct: 6, at: DateTime(2026, 3, 2, 10)));
    await play(s, quiz(correct: 6, at: DateTime(2026, 3, 4, 10))); // Lücke
    expect(s.playStreak, 1);
    expect(s.playStreakLongest, 2);
  });

  test('Können: 25 richtige in Folge über Quizze -> Eisern', () async {
    await play(s, quiz(correct: 10));
    await play(s, quiz(correct: 10));
    expect(s.isUnlocked('koennen_05'), isFalse); // erst 20
    await play(s, quiz(correct: 10));
    expect(s.reachedIron, isTrue);
    expect(s.isUnlocked('koennen_05'), isTrue);
  });

  test('Können: eine falsche Antwort bricht die laufende Serie', () async {
    await play(s, quiz(correct: 10));
    await play(s, quiz(correct: 9)); // letzte Frage falsch -> Reset auf 0
    expect(s.runningStreak, 0);
  });

  test('Können: 10 makellose Quizze -> Makellos + Scharfschütze', () async {
    for (var i = 0; i < 10; i++) {
      await play(s, quiz(correct: 10, at: DateTime(2026, 4, 1, 12)));
    }
    expect(s.perfectQuizzes, 10);
    expect(s.isUnlocked('koennen_01'), isTrue);
    expect(s.isUnlocked('koennen_04'), isTrue);
  });

  test('Block 4: 30 richtige je Bereich -> Themen-Abzeichen', () async {
    for (var i = 0; i < 3; i++) {
      await play(s, quiz(correct: 10, cat: 'torah'));
    }
    expect(s.areaCorrect['thema_01'], 30);
    expect(s.isUnlocked('thema_01'), isTrue);
  });

  test('Block 5: Frühaufsteher nur bei makellosem Quiz vor 7 Uhr', () async {
    await play(s, quiz(correct: 9, at: DateTime(2026, 5, 1, 6)));
    expect(s.isUnlocked('koennen_06'), isFalse); // nicht makellos
    await play(s, quiz(correct: 10, at: DateTime(2026, 5, 1, 6)));
    expect(s.isUnlocked('koennen_06'), isTrue);
  });

  testWidgets('Achievements-Screen rendert ohne Fehler', (tester) async {
    reset(s);
    await play(s, quiz(correct: 6, at: DateTime(2026, 2, 1, 12))); // etwas Fortschritt
    await tester.pumpWidget(const MaterialApp(home: AchievementsScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('/ 30'), findsWidgets); // Gesamtfortschritt X / 30
    // Nach unten scrollen -> versteckte Achievements (Block 5) als "???" sichtbar.
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 10; i++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump();
    }
    expect(find.text('???'), findsWidgets); // versteckte Achievements als Platzhalter
    expect(tester.takeException(), isNull);
  });

  test('Komplettist: Fixpunkt schaltet nach letztem Achievement frei', () async {
    // Alle 28 außer geheim_03 (Schmaler Pfad) und geheim_04 (Komplettist).
    final now = DateTime(2026, 1, 1).toIso8601String();
    for (final a in s.catalog) {
      if (a.id != 'geheim_03' && a.id != 'geheim_04') s.unlocked[a.id] = now;
    }
    expect(s.isUnlocked('geheim_04'), isFalse);
    final newly = await s.markNarrowPath(); // löst geheim_03 -> dann geheim_04
    final ids = newly.map((a) => a.id).toSet();
    expect(ids.contains('geheim_03'), isTrue);
    expect(ids.contains('geheim_04'), isTrue);
  });
}
