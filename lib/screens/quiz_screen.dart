import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/question.dart';
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
    with SingleTickerProviderStateMixin {
  late final List<Question> _questions;
  late final AnimationController _timer;
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final List<bool> _results = [];
  String? _picked;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final shuffled = widget.pool.toList()..shuffle(Random(20260606));
    _questions = shuffled.take(min(_roundLength, shuffled.length)).toList();
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _secondsPerQuestion),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_locked) _onPick(null);
      });
    _timer.forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Question get _current => _questions[_index];

  void _onPick(String? option) {
    if (_locked) return;
    _timer.stop();
    final correct = option != null && _current.isCorrect(option);
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
    Future.delayed(const Duration(milliseconds: 1400), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _questions.length) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: _score,
          results: _results,
          bestStreak: _bestStreak,
          title: widget.title,
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

  @override
  Widget build(BuildContext context) {
    final q = _current;
    return Scaffold(
      body: Starfield(
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
                      child: Text(
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
        const SizedBox(width: 8),
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
    return AnimatedBuilder(
      animation: _timer,
      builder: (_, _) {
        final remaining = 1 - _timer.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _locked ? remaining : remaining,
            minHeight: 4,
            backgroundColor: AppColors.cardBorder,
            valueColor: AlwaysStoppedAnimation(
              Color.lerp(AppColors.wrong, AppColors.gold, remaining)!,
            ),
          ),
        );
      },
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
