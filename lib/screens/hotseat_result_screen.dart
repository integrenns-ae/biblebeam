import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';

class HotseatResultScreen extends StatelessWidget {
  final String name1;
  final String name2;
  final int score1;
  final int score2;
  final int total1;
  final int total2;
  const HotseatResultScreen({
    super.key,
    required this.name1,
    required this.name2,
    required this.score1,
    required this.score2,
    required this.total1,
    required this.total2,
  });

  @override
  Widget build(BuildContext context) {
    final draw = score1 == score2;
    final p1Wins = score1 > score2;
    final winnerName = p1Wins ? name1 : name2;
    final winnerColor = p1Wins ? AppColors.player1 : AppColors.player2;

    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                if (draw)
                  Icon(Icons.handshake_rounded,
                          size: 96, color: AppColors.cream)
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutBack)
                      .then()
                      .shimmer(duration: 1600.ms, color: AppColors.cream)
                else
                  // Sieger-Pokal hüpft dauerhaft. RepaintBoundary + fester
                  // Platzhalter: nur der Pokal wird neu gezeichnet, nicht
                  // der ganze Screen (Performance auf Handys).
                  SizedBox(
                    height: 96 + 26,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: RepaintBoundary(
                        child: Icon(Icons.emoji_events_rounded,
                                size: 96, color: winnerColor)
                            .animate(onPlay: (c) => c.repeat())
                            .moveY(
                                begin: 0,
                                end: -26,
                                duration: 350.ms,
                                curve: Curves.easeOut)
                            .then()
                            .moveY(
                                begin: -26,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.bounceOut),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  draw ? tr('draw') : '$winnerName ${tr('wins')}',
                  textAlign: TextAlign.center,
                  style: AppTheme.dark().textTheme.displaySmall!.copyWith(
                      color: draw ? AppColors.cream : winnerColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      height: 1.1),
                ).animate().fadeIn(delay: 300.ms).scaleXY(
                    begin: 0.9, end: 1, duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: 32),
                Row(
                  children: [
                    _scoreCard(name1, score1, total1, AppColors.player1,
                        p1Wins && !draw),
                    const SizedBox(width: 14),
                    _scoreCard(name2, score2, total2, AppColors.player2,
                        !p1Wins && !draw),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: Text(tr('home'),
                            style: AppTheme.ui(15,
                                w: FontWeight.w600, c: AppColors.cream)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(), // zurück zum Setup
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.nightDeep,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: Text(tr('rematch'),
                            style: AppTheme.ui(15, w: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreCard(String name, int score, int total, Color color, bool winner) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: winner ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: winner ? color : AppColors.cardBorder,
              width: winner ? 1.8 : 1),
          boxShadow: winner
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20)]
              : null,
        ),
        child: Column(
          children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.ui(18, w: FontWeight.w600, c: color)),
            const SizedBox(height: 6),
            Text('$score',
                style: AppTheme.ui(48, w: FontWeight.w800, c: AppColors.cream)),
            Text('/ $total',
                style: AppTheme.ui(14, c: AppColors.creamDim)),
          ],
        ),
      ),
    );
  }
}
