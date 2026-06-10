import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokale Spielstatistik (Offline). Später optional mit Online-Profil sync.
class StatsService {
  StatsService._();
  static final StatsService instance = StatsService._();

  late SharedPreferences _prefs;

  final ValueNotifier<int> gamesPlayed = ValueNotifier(0);
  final ValueNotifier<int> totalCorrect = ValueNotifier(0);
  final ValueNotifier<int> totalQuestions = ValueNotifier(0);
  final ValueNotifier<int> bestScore = ValueNotifier(0);
  final ValueNotifier<int> bestStreak = ValueNotifier(0);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    gamesPlayed.value = _prefs.getInt('gamesPlayed') ?? 0;
    totalCorrect.value = _prefs.getInt('totalCorrect') ?? 0;
    totalQuestions.value = _prefs.getInt('totalQuestions') ?? 0;
    bestScore.value = _prefs.getInt('bestScore') ?? 0;
    bestStreak.value = _prefs.getInt('bestStreak') ?? 0;
  }

  /// Nach einer beendeten Runde aufrufen.
  Future<void> recordGame({
    required int correct,
    required int questions,
    required int score,
    required int streak,
  }) async {
    gamesPlayed.value += 1;
    totalCorrect.value += correct;
    totalQuestions.value += questions;
    if (score > bestScore.value) bestScore.value = score;
    if (streak > bestStreak.value) bestStreak.value = streak;
    await _prefs.setInt('gamesPlayed', gamesPlayed.value);
    await _prefs.setInt('totalCorrect', totalCorrect.value);
    await _prefs.setInt('totalQuestions', totalQuestions.value);
    await _prefs.setInt('bestScore', bestScore.value);
    await _prefs.setInt('bestStreak', bestStreak.value);
  }

  int get accuracyPct =>
      totalQuestions.value == 0 ? 0 : (totalCorrect.value * 100 / totalQuestions.value).round();
}
