import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/strings.dart';
import '../services/sound_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';

class ResultScreen extends StatefulWidget {
  final int score;
  final List<bool> results;
  final int bestStreak;
  final String title;

  const ResultScreen({
    super.key,
    required this.score,
    required this.results,
    required this.bestStreak,
    required this.title,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int score = 0;
  List<bool> results = const [];
  int bestStreak = 0;

  @override
  void initState() {
    super.initState();
    score = widget.score;
    results = widget.results;
    bestStreak = widget.bestStreak;
    SoundService.instance.play(Sfx.finish);
    StatsService.instance.recordGame(
      correct: _correct,
      questions: results.length,
      score: score,
      streak: bestStreak,
    );
  }

  int get _correct => results.where((r) => r).length;

  String get _verse {
    final ratio = results.isEmpty ? 0 : _correct / results.length;
    if (ratio == 1) return '"Your word is a lamp to my feet." — Psalm 119:105';
    if (ratio >= 0.6) return '"Let your light shine before others." — Matthew 5:16';
    return '"The path of the righteous is like the morning light." — Proverbs 4:18';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(Icons.auto_awesome, size: 56, color: AppColors.goldBright)
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.easeOutBack)
                    .then()
                    .shimmer(duration: 1600.ms, color: AppColors.cream),
                const SizedBox(height: 18),
                Text('$_correct / ${results.length}',
                    style: AppTheme.dark().textTheme.displayMedium!.copyWith(
                        color: AppColors.cream, fontWeight: FontWeight.w600)),
                Text(tr('lightsKindled'),
                    style: AppTheme.ui(14, c: AppColors.creamDim)),
                const SizedBox(height: 24),
                _statRow(),
                const SizedBox(height: 28),
                _constellation(),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_verse,
                      textAlign: TextAlign.center,
                      style: AppTheme.dark().textTheme.titleMedium!.copyWith(
                          color: AppColors.gold,
                          fontStyle: FontStyle.italic,
                          height: 1.4)),
                ).animate().fadeIn(delay: 400.ms, duration: 700.ms),
                const Spacer(),
                _buttons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow() {
    Widget chip(IconData i, String label, String value) => Column(
          children: [
            Icon(i, color: AppColors.gold, size: 22),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.ui(18, w: FontWeight.w700)),
            Text(label, style: AppTheme.ui(11, c: AppColors.creamDim)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        chip(Icons.star_rounded, tr('scoreLbl'), '$score'),
        chip(Icons.local_fire_department_rounded, tr('bestStreakLbl'), '$bestStreak'),
      ],
    );
  }

  Widget _constellation() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: List.generate(results.length, (i) {
        final ok = results[i];
        return Icon(
          ok ? Icons.brightness_7_rounded : Icons.brightness_1_outlined,
          color: ok ? AppColors.gold : AppColors.cardBorder,
          size: ok ? 20 : 14,
          shadows: ok
              ? [const Shadow(color: AppColors.gold, blurRadius: 10)]
              : null,
        )
            .animate()
            .fadeIn(delay: (80 * i).ms, duration: 300.ms)
            .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1));
      }),
    );
  }

  Widget _buttons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40)),
            ),
            child: Text(tr('home'),
                style: AppTheme.ui(15, w: FontWeight.w600, c: AppColors.cream)),
          ),
        ),
      ],
    );
  }
}
