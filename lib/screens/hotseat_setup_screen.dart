import 'dart:math';
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';
import 'hotseat_game_screen.dart';

class HotseatSetupScreen extends StatefulWidget {
  final QuestionPack pack;
  final int difficulty; // Default für beide Spieler (0=alle -> 2)
  const HotseatSetupScreen({super.key, required this.pack, this.difficulty = 0});

  @override
  State<HotseatSetupScreen> createState() => _HotseatSetupScreenState();
}

class _HotseatSetupScreenState extends State<HotseatSetupScreen> {
  final _name1 = TextEditingController();
  final _name2 = TextEditingController();
  late int _diff1;
  late int _diff2;
  String? _category; // null = gemischt
  int _count = 6;

  @override
  void initState() {
    super.initState();
    final d = widget.difficulty > 0 ? widget.difficulty : 2;
    _diff1 = d;
    _diff2 = d;
  }

  @override
  void dispose() {
    _name1.dispose();
    _name2.dispose();
    super.dispose();
  }

  List<Question> _poolFor(int diff) {
    final base =
        _category == null ? widget.pack.questions : widget.pack.byCategory(_category!);
    return base.where((q) => q.difficulty == diff).toList();
  }

  void _start() {
    final rnd = Random(DateTime.now().millisecondsSinceEpoch);
    // Spieler 1 zuerst ziehen ...
    final q1 = (_poolFor(_diff1)..shuffle(rnd)).take(_count).toList();
    // ... Spieler 2 aus seinem Pool OHNE bereits vergebene Fragen (keine Dopplung im Spiel)
    final used = q1.map((q) => q.id).toSet();
    final q2 = (_poolFor(_diff2).where((q) => !used.contains(q.id)).toList()
          ..shuffle(rnd))
        .take(_count)
        .toList();
    if (q1.length < _count || q2.length < _count) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('noQuestions'))));
      return;
    }
    SoundService.instance.play(Sfx.tap);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HotseatGameScreen(
        questions1: q1,
        questions2: q2,
        name1: _name1.text.trim().isEmpty ? tr('player1') : _name1.text.trim(),
        name2: _name2.text.trim().isEmpty ? tr('player2') : _name2.text.trim(),
        diff1: _diff1,
        diff2: _diff2,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.cream),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(tr('duelSetup'),
                        style: AppTheme.ui(20, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(tr('handicapHint'),
                      style: AppTheme.ui(12, c: AppColors.creamDim)),
                ),
                const SizedBox(height: 16),
                _playerCard(_name1, tr('player1'), AppColors.player1, _diff1,
                    (v) => setState(() => _diff1 = v)),
                const SizedBox(height: 12),
                _playerCard(_name2, tr('player2'), AppColors.player2, _diff2,
                    (v) => setState(() => _diff2 = v)),
                const SizedBox(height: 24),
                Text(tr('category'),
                    style: AppTheme.ui(14, w: FontWeight.w600, c: AppColors.gold)),
                const SizedBox(height: 8),
                _categoryChips(),
                const SizedBox(height: 24),
                Text('${tr('rounds')} (${tr('player1')} & ${tr('player2')})',
                    style: AppTheme.ui(14, w: FontWeight.w600, c: AppColors.gold)),
                const SizedBox(height: 8),
                Row(
                  children: [4, 6, 8, 10].map((n) {
                    final sel = _count == n;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _count = n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.gold : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: sel ? AppColors.gold : AppColors.cardBorder),
                          ),
                          child: Text('$n',
                              style: AppTheme.ui(14,
                                  w: FontWeight.w700,
                                  c: sel ? AppColors.nightDeep : AppColors.cream)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _start,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: const LinearGradient(
                          colors: [AppColors.gold, AppColors.goldBright]),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            blurRadius: 20),
                      ],
                    ),
                    child: Text(tr('start'),
                        style: AppTheme.ui(17,
                            w: FontWeight.w700, c: AppColors.nightDeep)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerCard(TextEditingController c, String hint, Color accent, int diff,
      ValueChanged<int> onDiff) {
    final levels = [(1, tr('diffEasy')), (2, tr('diffMedium')), (3, tr('diffHard'))];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: c,
                  style: AppTheme.ui(16),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTheme.ui(16, c: AppColors.creamDim),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${tr('strength')}:  ',
                  style: AppTheme.ui(12, c: AppColors.creamDim)),
              ...levels.map((e) {
                final sel = diff == e.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      SoundService.instance.play(Sfx.tap);
                      onDiff(e.$1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? accent : AppColors.night,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: sel ? accent : AppColors.cardBorder),
                      ),
                      child: Text(e.$2,
                          style: AppTheme.ui(12,
                              w: FontWeight.w700,
                              c: sel ? AppColors.nightDeep : AppColors.cream)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChips() {
    final items = <(String?, String)>[
      (null, tr('mixed')),
      ...widget.pack.categories.map((c) => (c.slug, trCategory(c.slug, c.name))),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        final sel = _category == e.$1;
        return GestureDetector(
          onTap: () => setState(() => _category = e.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.gold : AppColors.cardBg,
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: sel ? AppColors.gold : AppColors.cardBorder),
            ),
            child: Text(e.$2,
                style: AppTheme.ui(13,
                    w: FontWeight.w600,
                    c: sel ? AppColors.nightDeep : AppColors.cream)),
          ),
        );
      }).toList(),
    );
  }
}
