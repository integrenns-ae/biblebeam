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

  Future<void> play(Sfx sfx) async {
    final settings = SettingsService.instance;
    if (!settings.soundEnabled.value) return;
    _ensure();
    final p = _players[sfx]!;
    try {
      await p.stop();
      await p.setVolume(settings.sfxVolume.value);
      await p.play(AssetSource(_files[sfx]!));
    } catch (_) {
      // Audio darf das Spiel nie blockieren.
    }
  }
}
