import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/difficulty_repository.dart';
import '../l10n/strings.dart';
import '../models/question.dart';
import '../models/quiz_outcome.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_tile.dart';
import '../widgets/comet_painter.dart';
import '../widgets/starfield.dart';
import '../widgets/supernova_overlay.dart';
import 'result_screen.dart';

const _roundLength = 10;

/// Zeit pro Frage nach Schwierigkeit: schwer 20 s (Basis), mittel +5 s,
/// leicht +10 s. Pro Frage bemessen, damit auch im „Alle"-Filter und bei
/// Kategorie-Spielen jede Frage ihre eigene Zeit bekommt.
int _secondsFor(Question q) => 20 + (3 - q.difficulty.clamp(1, 3)) * 5;

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
  late final AnimationController _flash; // weiße Supernova bei Zeitablauf
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final List<bool> _results = [];
  final List<AnsweredQuestion> _answered = []; // für Statistik/Achievements
  int _secs = 20; // Zeit der aktuellen Frage (schwierigkeitsabhängig)
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
    _secs = _secondsFor(_questions.first);
    _timer = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secs),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_locked) _onPick(null);
      });
    _flash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400));
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
    final elapsedMs = (_timer.value * _secs * 1000).round();
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
    if (correct) {
      SoundService.instance.playCorrect(streak: _streak);
    } else {
      SoundService.instance.play(Sfx.wrong);
    }
    // Bei Zeitablauf erst nach dem Vollweiß der Supernova umschalten -> die neue
    // Frage taucht dann aus dem ausblendenden Weiß auf.
    Future.delayed(Duration(milliseconds: timeout ? 2100 : 1400), _next);
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
      _secs = _secondsFor(_current);
      _picked = null;
      _locked = false;
    });
    _timer
      ..duration = Duration(seconds: _secs)
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
                ...q.options.map((o) => AnswerTile(
                      text: o,
                      state: _optionState(o),
                      locked: _locked,
                      onTap: () => _onPick(o),
                    )),
              ],
            ),
          ),
        ),
      ),
          SupernovaOverlay(progress: _flash),
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

  Widget _timerBar() => CometTimerBar(progress: _timer);

  AnswerState _optionState(String option) {
    if (!_locked) return AnswerState.normal;
    if (_current.isCorrect(option)) return AnswerState.correct;
    if (_picked == option) return AnswerState.wrongPicked;
    return AnswerState.dimmed;
  }
}
