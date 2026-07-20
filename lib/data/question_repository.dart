import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import 'content_sync.dart';

/// Liefert den Fragenkatalog je Sprache:
///   1. gebündeltes Asset (beim Deploy aktuell, sofort verfügbar, offline)
///   2. localStorage-Cache – nur wenn er MEHR Fragen hat als das Asset
///      (also neuer als dieser Build); sonst verdeckt ein alter Cache das Asset.
///   3. Hintergrund-Sync aus Supabase (gedrosselt) → aktualisiert den Cache
///      für die nächste Sitzung.
class QuestionRepository {
  final Map<String, QuestionPack> _memory = {};
  final Set<String> _refreshing = {};

  /// Verfügbare Inhalts-Sprachen (für andere fällt es auf Englisch zurück).
  static const _available = {'en', 'de', 'ru'};

  // Kurzer Takt während der aktiven Inhalts-/QA-Phase: Korrekturen erscheinen
  // nach einem App-Neustart. (Später ggf. wieder erhöhen.)
  static const _refreshInterval = Duration(minutes: 2);

  Future<QuestionPack> load(String lang) async {
    final code = _available.contains(lang) ? lang : 'en';
    final inMem = _memory[code];
    if (inMem != null) {
      _refreshInBackground(code);
      return inMem;
    }

    // Das gebündelte Asset ist beim Deploy aktuell -> sofort anzeigen (kein
    // blockierender Netzwerk-Fetch, der bei großem Bestand ins Timeout läuft).
    // Den localStorage-Cache nur bevorzugen, wenn er MEHR Fragen hat als das
    // Asset (also neuer als dieser Build) – ein veralteter, kleinerer Cache darf
    // das aktuelle Asset nicht verdecken. Die Hintergrund-Aktualisierung hält
    // den Cache für die nächste Sitzung frisch.
    final bundled = await _loadBundled(code);
    final cached = await _loadFromCache(code);
    final pack = (cached != null &&
            cached.questions.length > bundled.questions.length)
        ? cached
        : bundled;
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
