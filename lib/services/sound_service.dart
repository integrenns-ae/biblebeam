import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

enum Sfx { correct, wrong, tap, finish }

/// Spielt kurze SFX ab, respektiert die Sound-Einstellungen.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final Map<Sfx, AudioPlayer> _players = {};

  static const _files = {
    Sfx.correct: 'sounds/correct.wav',
    Sfx.wrong: 'sounds/wrong.wav',
    Sfx.tap: 'sounds/tap.wav',
    Sfx.finish: 'sounds/finish.wav',
  };

  void _ensure() {
    if (_players.isNotEmpty) return;
    for (final s in Sfx.values) {
      _players[s] = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    }
  }

  Future<void> play(Sfx sfx) => _playWithRate(sfx, 1.0);

  /// Richtige Antwort mit steigender Tonhöhe je nach Serie – hörbares Momentum.
  /// Rate 1.0 (Serie 1) bis ~1.48 (Serie 9+), gedeckelt.
  Future<void> playCorrect({int streak = 1}) {
    final steps = (streak - 1).clamp(0, 8);
    return _playWithRate(Sfx.correct, 1.0 + steps * 0.06);
  }

  Future<void> _playWithRate(Sfx sfx, double rate) async {
    final settings = SettingsService.instance;
    if (!settings.soundEnabled.value) return;
    _ensure();
    final p = _players[sfx]!;
    try {
      await p.stop();
      await p.setVolume(settings.sfxVolume.value);
      await p.setPlaybackRate(rate);
      await p.play(AssetSource(_files[sfx]!));
      // Auf Web greift die Rate teils erst nach dem Start des Elements.
      await p.setPlaybackRate(rate);
    } catch (_) {
      // Audio darf das Spiel nie blockieren.
    }
  }
}
