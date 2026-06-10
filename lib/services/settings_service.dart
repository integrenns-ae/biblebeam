import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-Einstellungen, dauerhaft via SharedPreferences.
/// Einfache Singleton-Lösung mit ValueNotifiers (kein riverpod nötig in Phase 1).
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;

  final ValueNotifier<bool> soundEnabled = ValueNotifier(true);
  final ValueNotifier<double> sfxVolume = ValueNotifier(0.8);
  final ValueNotifier<String> locale = ValueNotifier('en'); // 'en' | 'de' | 'ru'

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    soundEnabled.value = _prefs.getBool('soundEnabled') ?? true;
    sfxVolume.value = _prefs.getDouble('sfxVolume') ?? 0.8;
    locale.value = _prefs.getString('locale') ?? 'en';
  }

  Future<void> setLocale(String code) async {
    locale.value = code;
    await _prefs.setString('locale', code);
  }

  Future<void> setSoundEnabled(bool v) async {
    soundEnabled.value = v;
    await _prefs.setBool('soundEnabled', v);
  }

  Future<void> setSfxVolume(double v) async {
    sfxVolume.value = v;
    await _prefs.setDouble('sfxVolume', v);
  }
}
