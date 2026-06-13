import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_outcome.dart';

/// Meldet die Antworten eines Quiz an die globale, anonyme Statistik
/// (record_answers, SECURITY DEFINER) und liefert die qids zurück, die
/// korrekt beantwortet wurden UND global selten sind (<5%) – für „Schmaler Pfad".
class QuestionStatsRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Liefert die seltenen, korrekt getroffenen qids (leer bei Offline/Fehler).
  Future<List<String>> recordAnswers(QuizOutcome outcome) async {
    try {
      final items = outcome.answers
          .map((a) => {'qid': a.questionId, 'correct': a.correct})
          .toList();
      final res = await _db.rpc('record_answers', params: {'p_items': items});
      final rare = (res is Map ? res['rare'] : null) as List?;
      return rare?.cast<String>() ?? const [];
    } catch (_) {
      return const [];
    }
  }
}
