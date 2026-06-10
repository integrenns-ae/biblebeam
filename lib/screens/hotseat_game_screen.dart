import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';
import 'hotseat_result_screen.dart';

enum _Phase { answer, reveal }

class HotseatGameScreen extends StatefulWidget {
  final List<Question> questions1;
  final List<Question> questions2;
  final String name1;
  final String name2;
  final int diff1;
  final int diff2;
  const HotseatGameScreen({
    super.key,
    required this.questions1,
    required this.questions2,
    required this.name1,
    required this.name2,
    this.diff1 = 2,
    this.diff2 = 2,
  });

  @override
  State<HotseatGameScreen> createState() => _HotseatGameScreenState();
}

class _HotseatGameScreenState extends State<HotseatGameScreen> {
  int _i1 = 0;
  int _i2 = 0;
  int _score1 = 0;
  int _score2 = 0;
  int _turn = 1; // 1 oder 2
  _Phase _phase = _Phase.answer;
  String? _pick;

  int get _n1 => widget.questions1.length;
  int get _n2 => widget.questions2.length;
  bool get _isP1 => _turn == 1;
  Question get _q => _isP1 ? widget.questions1[_i1] : widget.questions2[_i2];
  Color get _color => _isP1 ? AppColors.player1 : AppColors.player2;
  String get _name => _isP1 ? widget.name1 : widget.name2;

  String _diffLabel(int d) =>
      d == 1 ? tr('diffEasy') : (d == 3 ? tr('diffHard') : tr('diffMedium'));

  void _answer(String option) {
    if (_phase != _Phase.answer) return;
    SoundService.instance.play(Sfx.tap);
    final correct = _q.isCorrect(option);
    setState(() {
      _pick = option;
      _phase = _Phase.reveal;
      if (correct) {
        if (_isP1) {
          _score1++;
        } else {
          _score2++;
        }
      }
    });
    SoundService.instance.play(correct ? Sfx.correct : Sfx.wrong);
  }

  void _next() {
    // aktuellen Spieler-Index weiterzählen
    if (_isP1) {
      _i1++;
    } else {
      _i2++;
    }
    if (_i1 >= _n1 && _i2 >= _n2) {
      SoundService.instance.play(Sfx.finish);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => HotseatResultScreen(
          name1: widget.name1,
          name2: widget.name2,
          score1: _score1,
          score2: _score2,
          total1: _n1,
          total2: _n2,
        ),
      ));
      return;
    }
    // nächster Zug: bevorzugt der andere Spieler, falls er noch Fragen hat
    final otherHasQuestions = _isP1 ? _i2 < _n2 : _i1 < _n1;
    setState(() {
      if (otherHasQuestions) _turn = _isP1 ? 2 : 1;
      _phase = _Phase.answer;
      _pick = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _scoreBar(),
                const SizedBox(height: 16),
                _turnBanner(),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        _q.question,
                        textAlign: TextAlign.center,
                        style: AppTheme.dark().textTheme.headlineSmall!.copyWith(
                              color: AppColors.cream,
                              height: 1.35,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                            ),
                      )
                          .animate(key: ValueKey('${_turn}_${_isP1 ? _i1 : _i2}'))
                          .fadeIn(duration: 250.ms)
                          .moveY(begin: 10, end: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._q.options.map(_optionTile),
                if (_phase == _Phase.reveal) ...[
                  const SizedBox(height: 4),
                  _nextButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBar() {
    Widget side(String name, int score, int answered, int total, int diff,
            Color color, bool active) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.16) : AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? color : AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ui(14, w: FontWeight.w600, c: color)),
                Text('$score',
                    style: AppTheme.ui(22, w: FontWeight.w800, c: AppColors.cream)),
                Text('${_diffLabel(diff)} · $answered/$total',
                    style: AppTheme.ui(10, c: AppColors.creamDim)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        side(widget.name1, _score1, _i1, _n1, widget.diff1, AppColors.player1, _isP1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('vs',
              style: AppTheme.ui(14, w: FontWeight.w700, c: AppColors.gold)),
        ),
        side(widget.name2, _score2, _i2, _n2, widget.diff2, AppColors.player2, !_isP1),
      ],
    );
  }

  Widget _turnBanner() {
    if (_phase == _Phase.reveal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gold),
        ),
        child: Text('${tr('correctAnswer')}: ${_q.answer}',
            style: AppTheme.ui(14, w: FontWeight.w700, c: AppColors.goldBright)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_forward_rounded, color: _color, size: 18),
          const SizedBox(width: 8),
          Text('$_name ${tr('yourTurn')}',
              style: AppTheme.ui(15, w: FontWeight.w700, c: _color)),
        ],
      ),
    ).animate(key: ValueKey('${_turn}_$_phase')).fadeIn(duration: 250.ms).scaleXY(begin: 0.96, end: 1);
  }

  Widget _optionTile(String option) {
    final reveal = _phase == _Phase.reveal;
    final isCorrect = _q.isCorrect(option);
    final picked = _pick == option;

    Color bg = AppColors.cardBg;
    Color border = AppColors.cardBorder;
    Color text = AppColors.cream;

    if (reveal) {
      if (isCorrect) {
        bg = AppColors.gold.withValues(alpha: 0.18);
        border = AppColors.gold;
        text = AppColors.goldBright;
      } else if (picked) {
        border = _color;
        text = AppColors.creamDim;
      } else {
        text = AppColors.creamDim.withValues(alpha: 0.6);
      }
    }

    return GestureDetector(
      onTap: reveal ? null : () => _answer(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.4),
          boxShadow: (reveal && isCorrect)
              ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 18)]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(option,
                    style: AppTheme.ui(18, w: FontWeight.w500, c: text))),
            if (reveal && isCorrect)
              const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20),
            if (reveal && picked && !isCorrect)
              Icon(Icons.close_rounded, color: _color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _nextButton() {
    return GestureDetector(
      onTap: _next,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient:
              const LinearGradient(colors: [AppColors.gold, AppColors.goldBright]),
        ),
        child: Text(tr('next'),
            style: AppTheme.ui(16, w: FontWeight.w700, c: AppColors.nightDeep)),
      ),
    );
  }
}
