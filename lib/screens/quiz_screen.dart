import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/difficulty_repository.dart';
import '../l10n/strings.dart';
import '../models/question.dart';
import '../models/quiz_outcome.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';
import 'result_screen.dart';

const _roundLength = 10;
const _secondsPerQuestion = 20;

class QuizScreen extends StatefulWidget {
  final List<Question> pool;
  final String title;
  final String? categorySlug;
  const QuizScreen({
    super.key,
    required this.pool,
    required this.title,
    this.categorySlug,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with TickerProviderStateMixin {
  late final List<Question> _questions;
  late final AnimationController _timer;
  late final AnimationController _flash; // weiße Explosions-Blende bei Zeitablauf
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final List<bool> _results = [];
  final List<AnsweredQuestion> _answered = []; // für Statistik/Achievements
  String? _picked;
  bool _locked = false;

  final _diffRepo = DifficultyRepository();
  final Set<String> _rated = {}; // pro Sitzung gemeldete Frage-IDs

  @override
  void initState() {
    super.initState();
    // Echter Zufall pro Runde (vorher fester Seed -> immer dieselben Fragen).
    // Auch die Antwort-Positionen werden je Runde neu gemischt.
    final rnd = Random();
    final shuffled = widget.pool.toList()..shuffle(rnd);
    _questions = shuffled
        .take(min(_roundLength, shuffled.length))
        .map((q) => Question(
              id: q.id,
              categories: q.categories,
              difficulty: q.difficulty,
              question: q.question,
              options: q.options.toList()..shuffle(rnd),
              answer: q.answer,
              reference: q.reference,
            ))
        .toList();
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _secondsPerQuestion),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_locked) _onPick(null);
      });
    _flash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _timer.forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    _flash.dispose();
    super.dispose();
  }

  Question get _current => _questions[_index];

  void _onPick(String? option) {
    if (_locked) return;
    _timer.stop();
    final timeout = option == null; // Komet hat das Ende erreicht -> Explosion
    if (timeout) _flash.forward(from: 0);
    final correct = option != null && _current.isCorrect(option);
    final elapsedMs = (_timer.value * _secondsPerQuestion * 1000).round();
    _answered.add(AnsweredQuestion(
      questionId: _current.id,
      difficulty: _current.difficulty,
      categories: _current.categories,
      correct: correct,
      elapsedMs: elapsedMs,
    ));
    setState(() {
      _picked = option;
      _locked = true;
      _results.add(correct);
      if (correct) {
        _streak++;
        _bestStreak = max(_bestStreak, _streak);
        // Punkte: Basis + Streak-Bonus + Zeitbonus
        final timeBonus = ((1 - _timer.value) * 50).round();
        _score += 100 + (_streak - 1) * 20 + timeBonus;
      } else {
        _streak = 0;
      }
    });
    SoundService.instance.play(correct ? Sfx.correct : Sfx.wrong);
    // Bei Zeitablauf länger warten, damit nach der Explosion die Auflösung sichtbar ist.
    Future.delayed(Duration(milliseconds: timeout ? 1900 : 1400), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      final outcome = QuizOutcome(
        answers: _answered,
        score: _score,
        bestStreak: _bestStreak,
        finishedAt: DateTime.now(),
      );
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: _score,
          results: _results,
          bestStreak: _bestStreak,
          title: widget.title,
          outcome: outcome,
        ),
      ));
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _locked = false;
    });
    _timer
      ..reset()
      ..forward();
  }

  String _diffLabel(int d) =>
      tr(d <= 1 ? 'diffEasy' : (d >= 3 ? 'diffHard' : 'diffMedium'));

  void _showRateSheet() {
    final q = _current;
    final already = _rated.contains(q.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('rateQuestion'),
                  textAlign: TextAlign.center,
                  style: AppTheme.ui(17, w: FontWeight.w700, c: AppColors.gold)),
              const SizedBox(height: 6),
              Text('${tr('rateCurrent')}: ${_diffLabel(q.difficulty)}',
                  textAlign: TextAlign.center,
                  style: AppTheme.ui(13, c: AppColors.creamDim)),
              const SizedBox(height: 18),
              if (already)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(tr('rateAlready'),
                      textAlign: TextAlign.center,
                      style: AppTheme.ui(15, w: FontWeight.w600, c: AppColors.gold)),
                )
              else ...[
                // Runter nur, wenn nicht schon leichteste Stufe.
                _rateButton(
                  icon: Icons.south_rounded,
                  label: tr('rateTooEasy'),
                  enabled: q.difficulty > 1,
                  onTap: () => _submitRating(q.id, -1, sheetCtx),
                ),
                const SizedBox(height: 10),
                // Hoch nur, wenn nicht schon schwerste Stufe.
                _rateButton(
                  icon: Icons.north_rounded,
                  label: tr('rateTooHard'),
                  enabled: q.difficulty < 3,
                  onTap: () => _submitRating(q.id, 1, sheetCtx),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rateButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final c = enabled ? AppColors.cream : AppColors.creamDim.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.indigo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? AppColors.cardBorder : AppColors.cardBorder.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTheme.ui(15, w: FontWeight.w500, c: c))),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(String questionId, int direction, BuildContext sheetCtx) async {
    setState(() => _rated.add(questionId));
    Navigator.of(sheetCtx).pop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('rateThanks')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    }
    // Netzwerk-Aufruf im Hintergrund; Fehler sind unkritisch (kein Login nötig).
    await _diffRepo.vote(questionId, direction);
  }

  /// Bibelstelle bei der Auflösung (zum Nachschlagen / bei Streitfällen).
  Widget _refChip(String reference) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(reference,
              style: AppTheme.ui(13, w: FontWeight.w600, c: AppColors.goldBright)),
        ],
      ),
    ).animate(key: ValueKey('ref_${_current.id}')).fadeIn(duration: 250.ms);
  }

  @override
  Widget build(BuildContext context) {
    final q = _current;
    return Scaffold(
      body: Stack(
        children: [
          Starfield(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 16),
                _progressLights(),
                const SizedBox(height: 8),
                _timerBar(),
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            q.question,
                            key: ValueKey(q.id),
                            textAlign: TextAlign.center,
                            style: AppTheme.dark().textTheme.headlineSmall!.copyWith(
                                  color: AppColors.cream,
                                  height: 1.35,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                ),
                          )
                              .animate(key: ValueKey(q.id))
                              .fadeIn(duration: 350.ms)
                              .moveY(begin: 12, end: 0),
                          if (_locked && q.reference != null) ...[
                            const SizedBox(height: 14),
                            _refChip(q.reference!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...q.options.map(_optionTile),
              ],
            ),
          ),
        ),
      ),
          _flashOverlay(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.creamDim),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(widget.title,
              textAlign: TextAlign.center,
              style: AppTheme.ui(16, w: FontWeight.w600, c: AppColors.gold)),
        ),
        // Streak-Flamme
        AnimatedScale(
          scale: _streak > 0 ? 1 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.goldBright, size: 20),
              Text(' $_streak',
                  style: AppTheme.ui(15, w: FontWeight.w700, c: AppColors.goldBright)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Crowd-Einstufung: Frage als zu leicht/zu schwer melden.
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tr('rateQuestion'),
          icon: Icon(
            _rated.contains(_current.id)
                ? Icons.outlined_flag_rounded
                : Icons.flag_outlined,
            size: 20,
            color: _rated.contains(_current.id)
                ? AppColors.gold
                : AppColors.creamDim,
          ),
          onPressed: _showRateSheet,
        ),
        SizedBox(
          width: 44,
          child: Text('${_index + 1}/${_questions.length}',
              textAlign: TextAlign.right,
              style: AppTheme.ui(13, c: AppColors.creamDim)),
        ),
      ],
    );
  }

  Widget _progressLights() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_questions.length, (i) {
        Color c;
        if (i < _results.length) {
          c = _results[i] ? AppColors.gold : AppColors.wrong;
        } else if (i == _index) {
          c = AppColors.cream.withValues(alpha: 0.7);
        } else {
          c = AppColors.cardBorder;
        }
        return Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
            boxShadow: (i < _results.length && _results[i])
                ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }

  Widget _timerBar() {
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: _timer,
        builder: (_, _) => CustomPaint(
          painter: _CometPainter(_timer.value),
          size: Size.infinite,
        ),
      ),
    );
  }

  /// Weiße Explosions-Blende, wenn der Komet das Ende erreicht (Zeitablauf).
  Widget _flashOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _flash,
          builder: (_, _) {
            final t = _flash.value;
            if (t == 0) return const SizedBox.shrink();
            // schnelles Aufblenden -> kurz halten -> ausklingen (ca. 1 s)
            final double op = t < 0.06
                ? t / 0.06
                : (t < 0.5 ? 1.0 : (1 - (t - 0.5) / 0.5));
            return Opacity(
              opacity: op.clamp(0.0, 1.0),
              child: const ColoredBox(color: Colors.white),
            );
          },
        ),
      ),
    );
  }

  Widget _optionTile(String option) {
    final isCorrect = _current.isCorrect(option);
    final isPicked = _picked == option;

    Color bg = AppColors.cardBg;
    Color border = AppColors.cardBorder;
    Color text = AppColors.cream;
    Widget? trailing;

    if (_locked) {
      if (isCorrect) {
        bg = AppColors.gold.withValues(alpha: 0.18);
        border = AppColors.gold;
        text = AppColors.goldBright;
        trailing = const Icon(Icons.check_circle_rounded, color: AppColors.gold);
      } else if (isPicked) {
        bg = AppColors.wrong.withValues(alpha: 0.14);
        border = AppColors.wrong;
        text = AppColors.creamDim;
        trailing =
            const Icon(Icons.remove_circle_outline_rounded, color: AppColors.wrong);
      } else {
        text = AppColors.creamDim.withValues(alpha: 0.6);
      }
    }

    Widget tile = GestureDetector(
      onTap: _locked ? null : () => _onPick(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.4),
          boxShadow: (_locked && isCorrect)
              ? [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(option, style: AppTheme.ui(18, w: FontWeight.w500, c: text))),
            ?trailing,
          ],
        ),
      ),
    );

    // Richtige Antwort leuchtet beim Aufdecken kurz auf.
    if (_locked && isCorrect) {
      tile = tile.animate().shimmer(duration: 900.ms, color: AppColors.goldBright);
    }
    return tile;
  }
}

/// Timer als Komet: heller Kopf, der von links nach rechts fliegt, mit
/// ausklingendem Gold-Schweif dahinter. Erreicht der Kopf das Ende (Zeitablauf),
/// löst die Explosions-Blende aus (siehe _flashOverlay).
class _CometPainter extends CustomPainter {
  final double progress; // 0..1 verstrichene Zeit (Kopf wandert links -> rechts)
  const _CometPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, cy = size.height / 2;
    final headX = progress.clamp(0.0, 1.0) * w;

    // Basis-Schiene (dezent)
    canvas.drawLine(
      Offset(0, cy),
      Offset(w, cy),
      Paint()
        ..color = AppColors.cardBorder.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (headX <= 0.5) return;

    final tailLen = headX < w * 0.30 ? headX : w * 0.30;
    final tailStart = headX - tailLen;

    // weicher, breiter Glüh-Schweif
    final glowRect = Rect.fromLTRB(tailStart, cy - 5, headX, cy + 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.gold.withValues(alpha: 0), AppColors.gold.withValues(alpha: 0.35)],
        ).createShader(glowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // kompakter Kern-Schweif
    final rect = Rect.fromLTRB(tailStart, cy - 2.5, headX, cy + 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.gold.withValues(alpha: 0), AppColors.goldBright],
        ).createShader(rect),
    );

    // Komet-Kopf: Glühen + heller Kern
    canvas.drawCircle(
      Offset(headX, cy),
      9,
      Paint()
        ..color = AppColors.goldBright.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(Offset(headX, cy), 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _CometPainter old) => old.progress != progress;
}
