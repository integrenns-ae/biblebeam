import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

/// Lädt die gebündelten Offline-Fragenkataloge je Sprache aus den Assets.
/// (Später: Sync mit Supabase + Content-Pack-Versionierung.)
class QuestionRepository {
  final Map<String, QuestionPack> _cache = {};

  /// Verfügbare Inhalts-Sprachen (für andere fällt es auf Englisch zurück).
  static const _available = {'en', 'de'};

  Future<QuestionPack> load(String lang) async {
    final code = _available.contains(lang) ? lang : 'en';
    final cached = _cache[code];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/questions_$code.json');
    final pack = QuestionPack.fromJson(json.decode(raw) as Map<String, dynamic>);
    _cache[code] = pack;
    return pack;
  }
}
