import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/question.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_tile.dart';
import '../widgets/comet_painter.dart';
import '../widgets/difficulty_tag.dart';
import '../widgets/starfield.dart';
import '../widgets/supernova_overlay.dart';
import 'survival_result_screen.dart';

const _startLives = 3;
const _baseSeconds = 20;
const _minSeconds = 8;

/// Endlos-/Survival-Modus: 3 Leben, unbegrenzte Fragen, wachsender Zeitdruck.
/// Ein Fehler (falsch oder Timeout) kostet ein Leben; bei 0 ist Schluss.
class SurvivalScreen extends StatefulWidget {
  final List<Question> pool;
  final String title;
  const SurvivalScreen({super.key, required this.pool, required this.title});

  @override
  State<SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<SurvivalScreen>
    with TickerProviderStateMixin {
  static const _heartColor = Color(0xFFE06A7A);

  late final AnimationController _timer;
  late final AnimationController _flash; // weiße Supernova bei Zeitablauf

  final _rnd = Random();
  late final List<Question> _deck; // gemischter Vorrat, wird bei Erschöpfung neu gemischt
  int _deckPos = 0;

  late Question _current;
  int _secs = _baseSeconds;

  int _lives = _startLives;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _correct = 0; // Distanz = richtige Antworten (Headline-Metrik)
  int _answered = 0; // gesamte gestellte Fragen
  String? _picked;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _deck = widget.pool.toList()..shuffle(_rnd);
    _current = _drawQuestion();
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _baseSeconds),
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

  /// Zieht die nächste Frage; mischt die Antwort-Optionen neu. Bei erschöpftem
  /// Vorrat wird neu gemischt (Wiederholungen erst nach kompletter Runde).
  Question _drawQuestion() {
    if (_deckPos >= _deck.length) {
      _deck.shuffle(_rnd);
      _deckPos = 0;
    }
    final q = _deck[_deckPos++];
    return Question(
      id: q.id,
      categories: q.categories,
      difficulty: q.difficulty,
      question: q.question,
      options: q.options.toList()..shuffle(_rnd),
      answer: q.answer,
      reference: q.reference,
    );
  }

  int get _secondsForNext => max(_minSeconds, _baseSeconds - _correct ~/ 5);

  void _onPick(String? option) {
    if (_locked) return;
    _timer.stop();
    final timeout = option == null;
    if (timeout) _flash.forward(from: 0);
    final correct = option != null && _current.isCorrect(option);
    setState(() {
      _picked = option;
      _locked = true;
      _answered++;
      if (correct) {
        _correct++;
        _streak++;
        _bestStreak = max(_bestStreak, _streak);
        final timeBonus = ((1 - _timer.value) * 50).round();
        _score += 100 + (_streak - 1) * 20 + timeBonus;
      } else {
        _streak = 0;
        _lives--;
      }
    });
    if (correct) {
      SoundService.instance.playCorrect(streak: _streak);
    } else {
      SoundService.instance.play(Sfx.wrong);
    }
    // Bei Zeitablauf erst nach dem Vollweiß der Supernova umschalten.
    Future.delayed(Duration(milliseconds: timeout ? 880 : 1400), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_lives <= 0) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SurvivalResultScreen(
          correct: _correct,
          questions: _answered,
          score: _score,
          bestStreak: _bestStreak,
          pool: widget.pool,
          title: widget.title,
        ),
      ));
      return;
    }
    setState(() {
      _current = _drawQuestion();
      _secs = _secondsForNext;
      _picked = null;
      _locked = false;
    });
    _timer
      ..duration = Duration(seconds: _secs)
      ..reset()
      ..forward();
  }

  AnswerState _optionState(String option) {
    if (!_locked) return AnswerState.normal;
    if (_current.isCorrect(option)) return AnswerState.correct;
    if (_picked == option) return AnswerState.wrongPicked;
    return AnswerState.dimmed;
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
                    CometTimerBar(
                      progress: _timer,
                      base: DifficultyStyle.of(q.difficulty).base,
                      bright: DifficultyStyle.of(q.difficulty).bright,
                    ),
                    const SizedBox(height: 10),
                    DifficultyTag(difficulty: q.difficulty),
                    const SizedBox(height: 18),
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
                                style: AppTheme.dark()
                                    .textTheme
                                    .headlineSmall!
                                    .copyWith(
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
        // Leben als Herzen
        Row(
          children: List.generate(_startLives, (i) {
            final alive = i < _lives;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                alive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 20,
                color: alive ? _heartColor : AppColors.cardBorder,
              ),
            );
          }),
        ),
        const Spacer(),
        // Serie
        AnimatedScale(
          scale: _streak > 0 ? 1 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.goldBright, size: 20),
              Text(' $_streak',
                  style:
                      AppTheme.ui(15, w: FontWeight.w700, c: AppColors.goldBright)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Score
        Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
            const SizedBox(width: 2),
            Text('$_score',
                style: AppTheme.ui(15, w: FontWeight.w700, c: AppColors.cream)),
          ],
        ),
      ],
    );
  }

  /// Bibelstelle bei der Auflösung.
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

}
