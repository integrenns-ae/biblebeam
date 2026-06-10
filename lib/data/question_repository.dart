import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import 'content_sync.dart';

/// Liefert den Fragenkatalog je Sprache – mit drei Quellen:
///   1. lokaler Cache (zuletzt aus Supabase synchronisiert)
///   2. gebündeltes Asset (Fallback, sofort verfügbar, offline)
///   3. Hintergrund-Sync aus Supabase (max. alle 6 h) → aktualisiert den Cache
/// Review-Korrekturen erscheinen damit spätestens beim nächsten App-Start.
class QuestionRepository {
  final Map<String, QuestionPack> _memory = {};
  final Set<String> _refreshing = {};

  /// Verfügbare Inhalts-Sprachen (für andere fällt es auf Englisch zurück).
  static const _available = {'en', 'de'};

  static const _refreshInterval = Duration(hours: 6);

  Future<QuestionPack> load(String lang) async {
    final code = _available.contains(lang) ? lang : 'en';
    final cached = _memory[code];
    if (cached != null) {
      _refreshInBackground(code);
      return cached;
    }

    QuestionPack? pack = await _loadFromCache(code);
    pack ??= await _loadBundled(code);
    _memory[code] = pack;
    _refreshInBackground(code);
    return pack;
  }

  Future<QuestionPack> _loadBundled(String code) async {
    final raw = await rootBundle.loadString('assets/questions_$code.json');
    return QuestionPack.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<QuestionPack?> _loadFromCache(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('content_$code');
      if (raw == null) return null;
      final pack = QuestionPack.fromJson(json.decode(raw) as Map<String, dynamic>);
      // Plausibilität: kaputter/leerer Cache wird ignoriert
      if (pack.questions.length < 100) return null;
      return pack;
    } catch (_) {
      return null;
    }
  }

  /// Holt frische Inhalte aus Supabase (gedrosselt) und legt sie in den Cache.
  /// Fehler (offline etc.) sind unkritisch – das Spiel läuft mit Asset/Cache.
  void _refreshInBackground(String code) {
    if (_refreshing.contains(code)) return;
    _refreshing.add(code);
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final last = prefs.getInt('content_time_$code') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - last < _refreshInterval.inMilliseconds) return;

        final packJson = await ContentSync().fetchPack(code);
        if (packJson != null && (packJson['questions'] as List).length >= 100) {
          await prefs.setString('content_$code', json.encode(packJson));
          await prefs.setInt('content_time_$code', now);
          debugPrint('Content-Sync ($code): '
              '${(packJson['questions'] as List).length} Fragen aktualisiert');
        }
      } catch (e) {
        debugPrint('Content-Sync ($code) übersprungen: $e');
      } finally {
        _refreshing.remove(code);
      }
    }();
  }
}
