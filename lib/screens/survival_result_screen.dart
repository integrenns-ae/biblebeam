import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/sound_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';
import 'survival_screen.dart';

/// Ergebnis eines Endlos-Laufs: Distanz (richtige Antworten), Score, Bestwert.
class SurvivalResultScreen extends StatefulWidget {
  final int correct;
  final int questions;
  final int score;
  final int bestStreak;
  final List<Question> pool;
  final String title;

  const SurvivalResultScreen({
    super.key,
    required this.correct,
    required this.questions,
    required this.score,
    required this.bestStreak,
    required this.pool,
    required this.title,
  });

  @override
  State<SurvivalResultScreen> createState() => _SurvivalResultScreenState();
}

class _SurvivalResultScreenState extends State<SurvivalResultScreen> {
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    SoundService.instance.play(Sfx.finish);
    _finalize();
  }

  Future<void> _finalize() async {
    final best = await StatsService.instance.recordSurvival(
      correct: widget.correct,
      questions: widget.questions,
    );
    if (mounted) setState(() => _isNewBest = best);
  }

  void _retry() {
    SoundService.instance.play(Sfx.tap);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => SurvivalScreen(pool: widget.pool, title: widget.title),
    ));
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
                Icon(Icons.all_inclusive_rounded,
                        size: 52, color: AppColors.goldBright)
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.easeOutBack)
                    .then()
                    .shimmer(duration: 1600.ms, color: AppColors.cream),
                const SizedBox(height: 14),
                Text(tr('gameOver'),
                    style: AppTheme.ui(15, w: FontWeight.w600, c: AppColors.creamDim)),
                const SizedBox(height: 10),
                // Distanz = richtige Antworten, die Headline-Zahl.
                Text('${widget.correct}',
                    style: AppTheme.dark().textTheme.displayLarge!.copyWith(
                        color: AppColors.cream, fontWeight: FontWeight.w700)),
                Text(tr('survived'),
                    style: AppTheme.ui(14, c: AppColors.creamDim)),
                if (_isNewBest) ...[
                  const SizedBox(height: 12),
                  _newBestBadge(),
                ],
                const SizedBox(height: 26),
                _statRow(),
                const Spacer(),
                _buttons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newBestBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 6),
          Text(tr('newBest'),
              style: AppTheme.ui(14, w: FontWeight.w700, c: AppColors.goldBright)),
        ],
      ),
    ).animate().scale(
        delay: 300.ms, duration: 400.ms, curve: Curves.easeOutBack);
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
        chip(Icons.star_rounded, tr('scoreLbl'), '${widget.score}'),
        chip(Icons.local_fire_department_rounded, tr('bestStreakLbl'),
            '${widget.bestStreak}'),
        chip(Icons.emoji_events_rounded, tr('survivalBest'),
            '${StatsService.instance.survivalBest.value}'),
      ],
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
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
            ),
            child: Text(tr('home'),
                style: AppTheme.ui(15, w: FontWeight.w600, c: AppColors.cream)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _retry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
            ),
            child: Text(tr('retry'),
                style: AppTheme.ui(15, w: FontWeight.w700, c: AppColors.nightDeep)),
          ),
        ),
      ],
    );
  }
}
