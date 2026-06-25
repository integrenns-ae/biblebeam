import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewOption {
  final String id;
  final int sort;
  bool isCorrect;
  String text;
  ReviewOption({required this.id, required this.sort, required this.isCorrect, required this.text});
}

class ReviewQuestion {
  final String id;
  final int difficulty;
  String prompt;
  final List<ReviewOption> options;
  ReviewQuestion({
    required this.id,
    required this.difficulty,
    required this.prompt,
    required this.options,
  });
}

/// Lädt/Speichert Fragen für den Review-Modus über Supabase.
///
/// Lesen läuft über den anon-Key (nur approved Fragen, wie im Spiel).
/// Schreiben läuft über die SECURITY-DEFINER-RPC [review_save_question], die
/// den Zugangscode serverseitig prüft — kein Admin-Login im Client.
class ReviewRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Prüft den Zugangscode serverseitig (Gate beim Betreten des Reviews).
  Future<bool> checkCode(String code) async {
    final ok = await _db.rpc('review_check_code', params: {'p_code': code});
    return ok == true;
  }

  /// Kategorien (Roh-Tags) für den Filter.
  Future<List<({String slug, String? kind})>> fetchCategories() async {
    final rows = await _db.from('categories').select('slug, kind').order('kind').order('sort');
    return (rows as List)
        .map((r) => (slug: r['slug'] as String, kind: r['kind'] as String?))
        .toList();
  }

  /// Fragen laden (optional nach Kategorie-Slug gefiltert), Texte/Optionen in [lang].
  Future<List<ReviewQuestion>> fetchQuestions({
    String? categorySlug,
    required String lang,
    int limit = 400,
  }) async {
    const cols =
        'id, difficulty, question_translations(lang, prompt), answer_options(id, sort, is_correct, answer_option_translations(lang, text))';
    late final List data;
    if (categorySlug == null) {
      data = await _db.from('questions').select(cols).order('id').limit(limit);
    } else {
      data = await _db
          .from('questions')
          .select('$cols, question_categories!inner(categories!inner(slug))')
          .eq('question_categories.categories.slug', categorySlug)
          .order('id')
          .limit(limit);
    }

    String pick(List? trs) {
      final list = (trs ?? const []).cast<Map<String, dynamic>>();
      final m = list.firstWhere((t) => t['lang'] == lang, orElse: () => const {});
      if (m.isNotEmpty) return (m['prompt'] ?? m['text'] ?? '') as String;
      final en = list.firstWhere((t) => t['lang'] == 'en', orElse: () => const {});
      return (en['prompt'] ?? en['text'] ?? '') as String;
    }

    return data.map<ReviewQuestion>((q) {
      final opts = ((q['answer_options'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map((o) => ReviewOption(
                id: o['id'] as String,
                sort: (o['sort'] as num?)?.toInt() ?? 0,
                isCorrect: o['is_correct'] as bool? ?? false,
                text: pick(o['answer_option_translations'] as List?),
              ))
          .toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));
      return ReviewQuestion(
        id: q['id'] as String,
        difficulty: (q['difficulty'] as num?)?.toInt() ?? 2,
        prompt: pick(q['question_translations'] as List?),
        options: opts,
      );
    }).toList();
  }

  /// Korrekturen einer Frage in der gewählten Sprache speichern.
  /// [code] = der serverseitig geprüfte Zugangscode der Session.
  Future<void> saveQuestion(ReviewQuestion q, String lang, String code) async {
    await _db.rpc('review_save_question', params: {
      'p_code': code,
      'p_question_id': q.id,
      'p_lang': lang,
      'p_prompt': q.prompt.trim(),
      'p_options': q.options
          .map((o) => {
                'id': o.id,
                'text': o.text.trim(),
                'is_correct': o.isCorrect,
              })
          .toList(),
    });
  }
}
