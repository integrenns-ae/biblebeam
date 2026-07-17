import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';

/// Kleines Label „Leicht/Mittel/Schwer" mit farbigem Punkt in der
/// Schwierigkeitsfarbe (leicht = Hellblau, mittel = Gold, schwer = Rot).
/// Zeigt die Stufe der aktuellen Frage — auch im „Alle"-Filter, wo sie wechselt.
class DifficultyTag extends StatelessWidget {
  final int difficulty;
  const DifficultyTag({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final ds = DifficultyStyle.of(difficulty);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ds.bright,
            boxShadow: [
              BoxShadow(color: ds.base.withValues(alpha: 0.7), blurRadius: 7),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          tr(ds.labelKey).toUpperCase(),
          style: AppTheme.ui(12, w: FontWeight.w700, c: ds.bright)
              .copyWith(letterSpacing: 1.2),
        ),
      ],
    );
  }
}
