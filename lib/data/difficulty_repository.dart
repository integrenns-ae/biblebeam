import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Crowd-Einstufung: Spieler melden eine Frage als zu leicht/zu schwer.
/// Eine wirksame Stimme pro Geraet (stabile device_id in shared_preferences).
/// Die DB stuft bei +/-10 Netto-Differenz automatisch um (RPC, SECURITY DEFINER).
class DifficultyRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<String> _clientId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null || id.length < 8) {
      final r = Random();
      id = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  /// direction: +1 = zu schwer (Stufe hoch), -1 = zu leicht (Stufe runter).
  /// Liefert true bei Erfolg (offline/Fehler -> false, unkritisch).
  Future<bool> vote(String questionId, int direction) async {
    try {
      final cid = await _clientId();
      await _db.rpc('vote_question_difficulty', params: {
        'p_question_id': questionId,
        'p_client_id': cid,
        'p_direction': direction,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
