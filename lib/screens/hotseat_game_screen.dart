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

class _HotseatGameScreenState extends State<HotseatGameScreen>
    with SingleTickerProviderStateMixin {
  int _i1 = 0;
  int _i2 = 0;
  int _score1 = 0;
  int _score2 = 0;
  int _turn = 1; // 1 oder 2
  _Phase _phase = _Phase.answer;
  String? _pick;
  final List<bool> _res1 = []; // Ergebnis je beantworteter Frage (Spieler 1)
  final List<bool> _res2 = [];

  late final AnimationController _pulse; // Dauer-Puls für den aktiven Spieler

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int get _n1 => widget.questions1.length;
  int get _n2 => widget.questions2.length;
  bool get _isP1 => _turn == 1;
  int get _idx => _isP1 ? _i1 : _i2;
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
      if (_isP1) {
        _res1.add(correct);
        if (correct) _score1++;
      } else {
        _res2.add(correct);
        if (correct) _score2++;
      }
    });
    SoundService.instance.play(correct ? Sfx.correct : Sfx.wrong);
  }

  void _next() {
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
    final otherHasQuestions = _isP1 ? _i2 < _n2 : _i1 < _n1;
    SoundService.instance.play(Sfx.tap);
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
          child: LayoutBuilder(
            builder: (context, cons) {
              final wide = cons.maxWidth > 820;
              return Padding(
                padding: EdgeInsets.all(wide ? 28 : 16),
                child: Column(
                  children: [
                    _topBar(),
                    const SizedBox(height: 10),
                    Expanded(child: wide ? _wideLayout() : _narrowLayout()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _confirmLeave,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, size: 16, color: AppColors.creamDim),
                const SizedBox(width: 6),
                Text(tr('leave'),
                    style: AppTheme.ui(12, w: FontWeight.w600, c: AppColors.creamDim)),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Future<void> _confirmLeave() async {
    SoundService.instance.play(Sfx.tap);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr('leaveGame'),
            style: AppTheme.ui(17, w: FontWeight.w700, c: AppColors.cream)),
        content: Text(tr('leaveGameMsg'),
            style: AppTheme.ui(14, c: AppColors.creamDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel'), style: AppTheme.ui(14, c: AppColors.cream)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('leave'),
                style: AppTheme.ui(14, w: FontWeight.w700, c: AppColors.gold)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  // -------------------- Layouts --------------------
  Widget _narrowLayout() {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _playerCard(true, wide: false)),
              const SizedBox(width: 10),
              Expanded(child: _playerCard(false, wide: false)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _turnBanner(),
        const SizedBox(height: 14),
        Expanded(child: _stage(wide: false)),
      ],
    );
  }

  Widget _wideLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 248, child: _playerCard(true, wide: true)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  _turnBanner(),
                  const SizedBox(height: 20),
                  Expanded(child: _stage(wide: true)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(width: 248, child: _playerCard(false, wide: true)),
          ],
        ),
      ),
    );
  }

  /// Frage + Optionen + schwebender Weiter-Pfeil (überlagert, verdrängt nichts).
  Widget _stage({required bool wide}) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 4),
                    child: Text(
                      _q.question,
                      textAlign: TextAlign.center,
                      style: AppTheme.dark().textTheme.headlineSmall!.copyWith(
                            color: AppColors.cream,
                            height: 1.35,
                            fontSize: wide ? 34 : 28,
                            fontWeight: FontWeight.w600,
                          ),
                    )
                        .animate(key: ValueKey('q_${_turn}_$_idx'))
                        .fadeIn(duration: 350.ms)
                        .slideX(
                            begin: _isP1 ? -0.12 : 0.12,
                            end: 0,
                            curve: Curves.easeOutCubic)
                        .scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutBack),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _optionsArea(wide: wide),
          ],
        ),
        if (_phase == _Phase.reveal)
          Positioned(
            right: wide ? 4 : 0,
            top: 0,
            bottom: 0,
            child: Center(child: _nextArrow()),
          ),
      ],
    );
  }

  Widget _optionsArea({required bool wide}) {
    return LayoutBuilder(
      builder: (context, cons) {
        final itemW = wide ? (cons.maxWidth - 14) / 2 : cons.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 12,
          children: _q.options
              .map((o) => SizedBox(width: itemW, child: _optionTile(o)))
              .toList(),
        );
      },
    );
  }

  // -------------------- Spieler-Karte (Score als Sterne) --------------------
  Widget _playerCard(bool isP1, {required bool wide}) {
    final color = isP1 ? AppColors.player1 : AppColors.player2;
    final name = isP1 ? widget.name1 : widget.name2;
    final score = isP1 ? _score1 : _score2;
    final res = isP1 ? _res1 : _res2;
    final total = isP1 ? _n1 : _n2;
    final diff = isP1 ? widget.diff1 : widget.diff2;
    final active = _isP1 == isP1;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final p = _pulse.value; // 0..1
        return Container(
          padding: EdgeInsets.all(wide ? 16 : 11),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.12 + 0.10 * p)
                : AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active ? color : AppColors.cardBorder,
                width: active ? 2 : 1.2),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.20 + 0.45 * p),
                        blurRadius: 16 + 22 * p,
                        spreadRadius: 1),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    wide ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(Icons.person_rounded,
                      color: active ? color : AppColors.creamDim, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.ui(wide ? 16 : 14,
                            w: FontWeight.w700, c: color)),
                  ),
                ],
              ),
              SizedBox(height: wide ? 8 : 4),
              Text('$score',
                  style: AppTheme.dark().textTheme.displaySmall!.copyWith(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w800,
                        fontSize: wide ? 46 : 30,
                        shadows: active
                            ? [
                                Shadow(
                                    color: color.withValues(alpha: 0.5 + 0.4 * p),
                                    blurRadius: 16)
                              ]
                            : null,
                      )),
              Text('${_diffLabel(diff)} · ${res.length}/$total',
                  style: AppTheme.ui(wide ? 11 : 10, c: AppColors.creamDim)),
              SizedBox(height: wide ? 12 : 8),
              _pips(res, total, color, active, p, wide),
              if (active) ...[
                SizedBox(height: wide ? 10 : 6),
                Text(tr('yourTurn'),
                    style: AppTheme.ui(wide ? 12 : 10,
                        w: FontWeight.w700,
                        c: color.withValues(alpha: 0.55 + 0.45 * p))),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Ein Stern je Frage: gewonnen = glüht in Spielerfarbe (aktiv → flimmert),
  /// falsch = matter Umriss, noch offen = ganz blass.
  Widget _pips(List<bool> res, int total, Color color, bool active, double pulse,
      bool wide) {
    final sz = wide ? 26.0 : 17.0;
    return Wrap(
      spacing: wide ? 5 : 3,
      runSpacing: wide ? 5 : 3,
      alignment: wide ? WrapAlignment.center : WrapAlignment.start,
      children: List.generate(total, (i) {
        if (i < res.length) {
          if (res[i]) {
            final glow = active ? (0.55 + 0.45 * pulse) : 0.9;
            return Icon(Icons.star_rounded,
                size: sz,
                color: color,
                shadows: [
                  Shadow(color: color.withValues(alpha: glow), blurRadius: 12)
                ]);
          }
          return Icon(Icons.star_border_rounded,
              size: sz, color: AppColors.creamDim.withValues(alpha: 0.5));
        }
        return Icon(Icons.star_border_rounded,
            size: sz, color: AppColors.cardBorder);
      }),
    );
  }

  // -------------------- Banner (Zug / Auflösung) --------------------
  Widget _turnBanner() {
    if (_phase == _Phase.reveal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gold),
        ),
        child: Text('${tr('correctAnswer')}: ${_q.answer}',
            textAlign: TextAlign.center,
            style: AppTheme.ui(15, w: FontWeight.w700, c: AppColors.goldBright)),
      ).animate(key: ValueKey('rev_${_turn}_$_idx')).fadeIn(duration: 220.ms);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color, width: 2),
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: 0.35), blurRadius: 18)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: _color, size: 20),
          const SizedBox(width: 8),
          Text('$_name ${tr('yourTurn')}',
              style: AppTheme.ui(17, w: FontWeight.w800, c: _color)),
        ],
      ),
    )
        .animate(key: ValueKey('turn_${_turn}_$_idx'))
        .fadeIn(duration: 260.ms)
        .scaleXY(begin: 1.22, end: 1, curve: Curves.easeOutBack)
        .shimmer(duration: 900.ms, color: _color);
  }

  // -------------------- Option --------------------
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
                    style: AppTheme.ui(17, w: FontWeight.w500, c: text))),
            if (reveal && isCorrect)
              const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20),
            if (reveal && picked && !isCorrect)
              Icon(Icons.close_rounded, color: _color, size: 20),
          ],
        ),
      ),
    );
  }

  // -------------------- Weiter-Pfeil (schwebend, > als Vektor) --------------------
  Widget _nextArrow() {
    // Alles hit-test-sicher (Opacity/Transform schlucken keine Taps – anders als
    // flutter_animate-Einblendungen, die den Pfeil sonst unklickbar machen).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset((1 - t) * 26, 0), child: child),
      ),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final p = _pulse.value;
          return Transform.scale(
            scale: 1.0 + 0.06 * p,
            child: GestureDetector(
              key: const Key('hotseat-next'),
              onTap: _next,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldBright]),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.40 + 0.35 * p),
                        blurRadius: 18 + 12 * p,
                        spreadRadius: 1),
                  ],
                ),
                child: CustomPaint(painter: _ChevronPainter(AppColors.nightDeep)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Zeichnet ein sauberes „>" (Chevron) als Vektor.
class _ChevronPainter extends CustomPainter {
  final Color color;
  _ChevronPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.40, h * 0.28)
      ..lineTo(w * 0.66, h * 0.50)
      ..lineTo(w * 0.40, h * 0.72);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter old) => old.color != color;
}
