import 'package:flutter/material.dart';

import '../data/review_repository.dart';
import '../l10n/strings.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';
import 'review_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.cream),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(tr('settings'),
                        style: AppTheme.ui(20, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),
                _card(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: s.soundEnabled,
                    builder: (_, enabled, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.gold,
                      title: Text(tr('sound'), style: AppTheme.ui(16)),
                      subtitle: Text(tr('soundSub'),
                          style: AppTheme.ui(12, c: AppColors.creamDim)),
                      value: enabled,
                      onChanged: (v) {
                        s.setSoundEnabled(v);
                        if (v) SoundService.instance.play(Sfx.tap);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _card(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: s.soundEnabled,
                    builder: (_, enabled, _) => ValueListenableBuilder<double>(
                      valueListenable: s.sfxVolume,
                      builder: (_, vol, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('volume'), style: AppTheme.ui(16)),
                          Row(
                            children: [
                              const Icon(Icons.volume_down_rounded,
                                  color: AppColors.creamDim, size: 20),
                              Expanded(
                                child: Slider(
                                  value: vol,
                                  activeColor: AppColors.gold,
                                  inactiveColor: AppColors.cardBorder,
                                  onChanged: enabled
                                      ? (v) => s.setSfxVolume(v)
                                      : null,
                                  onChangeEnd: enabled
                                      ? (_) => SoundService.instance.play(Sfx.tap)
                                      : null,
                                ),
                              ),
                              const Icon(Icons.volume_up_rounded,
                                  color: AppColors.creamDim, size: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('language'), style: AppTheme.ui(16)),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<String>(
                          valueListenable: s.locale,
                          builder: (_, current, _) => Wrap(
                            spacing: 10,
                            children: supportedLangs.map((code) {
                              final selected = code == current;
                              return ChoiceChip(
                                label: Text(langLabels[code]!),
                                selected: selected,
                                showCheckmark: false,
                                labelStyle: AppTheme.ui(14,
                                    w: FontWeight.w600,
                                    c: selected
                                        ? AppColors.nightDeep
                                        : AppColors.cream),
                                selectedColor: AppColors.gold,
                                backgroundColor: AppColors.night,
                                side: const BorderSide(color: AppColors.cardBorder),
                                onSelected: (_) {
                                  s.setLocale(code);
                                  SoundService.instance.play(Sfx.tap);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(tr('contentNote'),
                            style: AppTheme.ui(11, c: AppColors.creamDim)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _openReview(context),
                  child: _card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.rate_review_rounded,
                              color: AppColors.creamDim, size: 20),
                          const SizedBox(width: 12),
                          Text(tr('review'), style: AppTheme.ui(16)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.creamDim),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text('Queezra · v1.0',
                      style: AppTheme.ui(12, c: AppColors.creamDim)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReview(BuildContext context) {
    final ctl = TextEditingController();
    String? err;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setLocal) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: Text(tr('enterCode'), style: AppTheme.ui(16, c: AppColors.cream)),
          content: TextField(
            controller: ctl,
            autofocus: true,
            obscureText: true,
            style: AppTheme.ui(16, c: AppColors.cream),
            cursorColor: AppColors.gold,
            decoration: InputDecoration(
              errorText: err,
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.cardBorder)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold)),
            ),
            onSubmitted: (_) => _trySubmit(dialogCtx, context, ctl.text, setLocal,
                (e) => err = e),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(tr('home'), style: AppTheme.ui(14, c: AppColors.creamDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.nightDeep),
              onPressed: () => _trySubmit(dialogCtx, context, ctl.text, setLocal,
                  (e) => err = e),
              child: Text(tr('load'), style: AppTheme.ui(14, w: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trySubmit(BuildContext dialogCtx, BuildContext pageCtx,
      String code,
      void Function(void Function()) setLocal,
      void Function(String?) setErr) async {
    final trimmed = code.trim();
    // Code wird serverseitig geprüft (kein Klartext-Vergleich im Client).
    bool ok;
    try {
      ok = await ReviewRepository().checkCode(trimmed);
    } catch (_) {
      ok = false;
    }
    if (ok) {
      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
      if (pageCtx.mounted) {
        Navigator.of(pageCtx).push(
            MaterialPageRoute(builder: (_) => ReviewScreen(code: trimmed)));
      }
    } else {
      setLocal(() => setErr(tr('wrongCode')));
    }
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}
