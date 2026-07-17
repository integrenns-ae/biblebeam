import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Timer als Komet: heller Kopf, der von links nach rechts fliegt, mit
/// ausklingendem Gold-Schweif dahinter. Erreicht der Kopf das Ende (Zeitablauf),
/// löst im aufrufenden Screen die Explosions-Blende aus.
///
/// Gemeinsam genutzt von Quick-Play (`quiz_screen`) und Endlos (`survival_screen`),
/// damit das Timer-Feeling an einer Stelle lebt.
class CometPainter extends CustomPainter {
  final double progress; // 0..1 verstrichene Zeit (Kopf wandert links -> rechts)
  final Color base; // Schweif-Grundfarbe (nach Schwierigkeit)
  final Color bright; // heller Kopf-/Schweif-Ton
  const CometPainter(this.progress,
      {this.base = AppColors.gold, this.bright = AppColors.goldBright});

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
          colors: [base.withValues(alpha: 0), base.withValues(alpha: 0.35)],
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
          colors: [base.withValues(alpha: 0), bright],
        ).createShader(rect),
    );

    // Kopf wächst in den letzten 20 % der Zeit stufenlos auf 300 % Größe.
    final p = progress.clamp(0.0, 1.0);
    final headScale = p <= 0.8 ? 1.0 : 1.0 + (p - 0.8) / 0.2 * 2.0;

    // Komet-Kopf: Glühen + heller Kern
    canvas.drawCircle(
      Offset(headX, cy),
      9 * headScale,
      Paint()
        ..color = bright.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * headScale),
    );
    canvas.drawCircle(
        Offset(headX, cy), 4.5 * headScale, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CometPainter old) =>
      old.progress != progress || old.base != base || old.bright != bright;
}

/// Kleiner Wrapper, der den Komet-Timer an einen Controller bindet.
/// `base`/`bright` färben den Schweif nach Schwierigkeit ein.
class CometTimerBar extends StatelessWidget {
  final Animation<double> progress;
  final Color base;
  final Color bright;
  const CometTimerBar({
    super.key,
    required this.progress,
    this.base = AppColors.gold,
    this.bright = AppColors.goldBright,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, _) => CustomPaint(
          painter: CometPainter(progress.value, base: base, bright: bright),
          size: Size.infinite,
        ),
      ),
    );
  }
}
