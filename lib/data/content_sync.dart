import 'package:supabase_flutter/supabase_flutter.dart';

/// Holt die freigegebenen Fragen aus Supabase und baut daraus ein
/// QuestionPack-JSON (gleiches Format wie die gebündelten Assets).
/// Regionen werden wie in scripts/lib/transform.mjs aus den Buch-Tags
/// abgeleitet (Dart-Port der BOOK_REGION-Zuordnung, Keys = DB-Slugs).
class ContentSync {
  static const _pageSize = 1000;

  static const _regions = [
    {'slug': 'torah', 'name': 'Law (Torah)'},
    {'slug': 'history', 'name': 'History of Israel'},
    {'slug': 'wisdom', 'name': 'Wisdom & Poetry'},
    {'slug': 'prophets', 'name': 'Prophets'},
    {'slug': 'gospels', 'name': 'Gospels (Jesus)'},
    {'slug': 'church', 'name': 'Early Church'},
    {'slug': 'revelation', 'name': 'Revelation'},
    {'slug': 'general', 'name': 'General Bible'},
  ];

  static const Map<String, String> _bookRegion = {
    // Tora
    'genesis': 'torah', 'exodus': 'torah', 'leviticus': 'torah',
    'numbers': 'torah', 'deuteronomy': 'torah',
    // Geschichte
    'joshua': 'history', 'judges': 'history', 'ruth': 'history',
    '1-samuel': 'history', '2-samuel': 'history', 'samuel': 'history',
    '1-kings': 'history', '2-kings': 'history', 'kings': 'history',
    'chronicles': 'history', '1-chronicles': 'history', '2-chronicles': 'history',
    'ezra': 'history', 'nehemiah': 'history', 'esther': 'history',
    // Weisheit
    'job': 'wisdom', 'psalms': 'wisdom', 'proverbs': 'wisdom',
    'ecclesiastes': 'wisdom', 'song-of-songs': 'wisdom',
    // Propheten
    'isaiah': 'prophets', 'jeremiah': 'prophets', 'lamentations': 'prophets',
    'ezekiel': 'prophets', 'daniel': 'prophets', 'hosea': 'prophets',
    'joel': 'prophets', 'amos': 'prophets', 'obadiah': 'prophets',
    'jonah': 'prophets', 'micah': 'prophets', 'nahum': 'prophets',
    'habakkuk': 'prophets', 'zephaniah': 'prophets', 'haggai': 'prophets',
    'zechariah': 'prophets', 'malachi': 'prophets',
    // Evangelien
    'matthew': 'gospels', 'mark': 'gospels', 'luke': 'gospels',
    'john': 'gospels', 'gospels': 'gospels',
    // Frühe Gemeinde
    'acts': 'church', 'romans': 'church', '1-corinthians': 'church',
    '2-corinthians': 'church', 'corinthians': 'church', 'galatians': 'church',
    'ephesians': 'church', 'philippians': 'church', 'colossians': 'church',
    '1-thessalonians': 'church', '2-thessalonians': 'church',
    'thessalonians': 'church', '1-timothy': 'church', '2-timothy': 'church',
    'timothy': 'church', 'titus': 'church', 'philemon': 'church',
    'hebrews': 'church', 'james': 'church', '1-peter': 'church',
    '2-peter': 'church', 'peter': 'church', '1-john': 'church',
    '2-john': 'church', '3-john': 'church', 'jude': 'church',
    // Offenbarung
    'revelation': 'revelation',
  };

  /// Lädt alle freigegebenen Fragen in [lang] und liefert Pack-JSON –
  /// oder null, wenn nichts Brauchbares ankam.
  Future<Map<String, dynamic>?> fetchPack(String lang) async {
    final db = Supabase.instance.client;
    final rows = <Map<String, dynamic>>[];

    var offset = 0;
    while (true) {
      final page = await db
          .from('questions')
          .select('id, difficulty, '
              'question_translations(prompt, explanation), '
              'answer_options(sort, is_correct, answer_option_translations(text)), '
              'question_categories(categories(slug, kind))')
          .eq('status', 'approved')
          .eq('question_translations.lang', lang)
          .eq('answer_options.answer_option_translations.lang', lang)
          .order('id')
          .range(offset, offset + _pageSize - 1);
      rows.addAll((page as List).cast<Map<String, dynamic>>());
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    final questions = <Map<String, dynamic>>[];
    final regionCounts = <String, int>{};

    for (final q in rows) {
      final trs = (q['question_translations'] as List?) ?? const [];
      if (trs.isEmpty) continue;
      final prompt = (trs.first['prompt'] as String?)?.trim() ?? '';
      if (prompt.isEmpty) continue;

      final opts = ((q['answer_options'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where((o) => ((o['answer_option_translations'] as List?) ?? const []).isNotEmpty)
          .toList()
        ..sort((a, b) =>
            ((a['sort'] as num?) ?? 0).compareTo((b['sort'] as num?) ?? 0));
      final texts = opts
          .map((o) =>
              ((o['answer_option_translations'] as List).first['text'] as String).trim())
          .toList();
      String? answer;
      for (var i = 0; i < opts.length; i++) {
        if (opts[i]['is_correct'] == true) answer = texts[i];
      }
      if (texts.length < 2 || answer == null) continue;

      // Regionen aus Buch-Tags ableiten
      final regions = <String>{};
      for (final qc in (q['question_categories'] as List?) ?? const []) {
        final cat = qc['categories'] as Map<String, dynamic>?;
        if (cat == null || cat['kind'] != 'book') continue;
        regions.add(_bookRegion[cat['slug']] ?? 'general');
      }
      if (regions.isEmpty) regions.add('general');
      for (final r in regions) {
        regionCounts[r] = (regionCounts[r] ?? 0) + 1;
      }

      final reference = (trs.first['explanation'] as String?)?.trim();
      questions.add({
        'id': q['id'],
        'categories': regions.toList(),
        'difficulty': (q['difficulty'] as num?)?.toInt() ?? 2,
        'question': prompt,
        'options': texts,
        'answer': answer,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      });
    }

    if (questions.isEmpty) return null;

    final categories = _regions
        .where((r) => (regionCounts[r['slug']] ?? 0) > 0)
        .map((r) => {
              'slug': r['slug'],
              'name': r['name'],
              'count': regionCounts[r['slug']],
            })
        .toList();

    return {
      'version': 2,
      'lang': lang,
      'categories': categories,
      'questions': questions,
    };
  }
}
