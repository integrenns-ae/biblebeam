/// Detailliertes Ergebnis eines abgeschlossenen Solo-Quiz – Grundlage für
/// Statistik, Achievements und die globale Antwort-Statistik.
class AnsweredQuestion {
  final String questionId;
  final int difficulty; // 1..3
  final List<String> categories; // Lichtpfad-Regionen
  final bool correct;
  final int elapsedMs; // Zeit bis zur Antwort (Timeout = volle Zeit)

  const AnsweredQuestion({
    required this.questionId,
    required this.difficulty,
    required this.categories,
    required this.correct,
    required this.elapsedMs,
  });
}

class QuizOutcome {
  final List<AnsweredQuestion> answers;
  final int score;
  final int bestStreak;
  final DateTime finishedAt; // lokale Zeit (für Tageszeit-/Serien-Logik)

  const QuizOutcome({
    required this.answers,
    required this.score,
    required this.bestStreak,
    required this.finishedAt,
  });

  int get correct => answers.where((a) => a.correct).length;
  int get total => answers.length;
  bool get isPerfect => total > 0 && correct == total;
}
