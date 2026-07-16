import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Darstellungszustand einer Antwort-Kachel nach dem Aufdecken.
enum AnswerState {
  /// Noch nicht aufgedeckt (antippbar) – neutrale Optik.
  normal,

  /// Die richtige Antwort (leuchtet auf, Shimmer + Glow).
  correct,

  /// Vom Spieler gewählte, falsche Antwort.
  wrongPicked,

  /// Aufgedeckt, aber weder richtig noch gewählt – gedimmt.
  dimmed,
}

/// Antwort-Kachel für Quick-Play und Endlos-Modus. Eine Quelle für Optik +
/// "Juice" (Farbwechsel, Glow, Shimmer bei richtig).
class AnswerTile extends StatelessWidget {
  final String text;
  final AnswerState state;
  final bool locked;
  final VoidCallback onTap;

  const AnswerTile({
    super.key,
    required this.text,
    required this.state,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.cardBg;
    Color border = AppColors.cardBorder;
    Color textColor = AppColors.cream;
    Widget? trailing;

    switch (state) {
      case AnswerState.normal:
        break;
      case AnswerState.correct:
        bg = AppColors.gold.withValues(alpha: 0.18);
        border = AppColors.gold;
        textColor = AppColors.goldBright;
        trailing = const Icon(Icons.check_circle_rounded, color: AppColors.gold);
      case AnswerState.wrongPicked:
        bg = AppColors.wrong.withValues(alpha: 0.14);
        border = AppColors.wrong;
        textColor = AppColors.creamDim;
        trailing =
            const Icon(Icons.remove_circle_outline_rounded, color: AppColors.wrong);
      case AnswerState.dimmed:
        textColor = AppColors.creamDim.withValues(alpha: 0.6);
    }

    Widget tile = GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.4),
          boxShadow: state == AnswerState.correct
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
                child: Text(text,
                    style: AppTheme.ui(18, w: FontWeight.w500, c: textColor))),
            ?trailing,
          ],
        ),
      ),
    );

    // Richtige Antwort leuchtet beim Aufdecken kurz auf.
    if (state == AnswerState.correct) {
      tile = tile.animate().shimmer(duration: 900.ms, color: AppColors.goldBright);
    }
    return tile;
  }
}
