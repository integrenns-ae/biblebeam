import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

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
/// Schreiben erfordert eine Reviewer-Sitzung (siehe [signInReviewer]).
class ReviewRepository {
  SupabaseClient get _db => Supabase.instance.client;

  bool get isSignedIn => _db.auth.currentSession != null;

  /// Meldet das Reviewer-Konto an. Wirft bei Fehler.
  Future<void> signInReviewer() async {
    if (!AppConfig.reviewerConfigured) {
      throw 'Reviewer-Konto noch nicht konfiguriert (lib/config.dart).';
    }
    await _db.auth.signInWithPassword(
      email: AppConfig.reviewerEmail,
      password: AppConfig.reviewerPassword,
    );
  }

  Future<void> signOut() => _db.auth.signOut();

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
  Future<void> saveQuestion(ReviewQuestion q, String lang) async {
    await _db.from('question_translations').upsert({
      'question_id': q.id,
      'lang': lang,
      'prompt': q.prompt.trim(),
    }, onConflict: 'question_id,lang');

    for (final o in q.options) {
      await _db.from('answer_option_translations').upsert({
        'option_id': o.id,
        'lang': lang,
        'text': o.text.trim(),
      }, onConflict: 'option_id,lang');
      await _db.from('answer_options').update({'is_correct': o.isCorrect}).eq('id', o.id);
    }
  }
}
